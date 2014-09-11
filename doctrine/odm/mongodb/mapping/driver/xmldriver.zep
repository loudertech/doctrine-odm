/*
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * This software consists of voluntary contributions made by many individuals
 * and is licensed under the MIT license. For more information, see
 * <http://www.doctrine-project.org>.
 */

namespace Doctrine\ODM\MongoDB\Mapping\Driver;

use Doctrine\Common\Persistence\Mapping\ClassMetadata;
use Doctrine\Common\Persistence\Mapping\Driver\FileDriver;
use Doctrine\ODM\MongoDB\Mapping\ClassMetadataInfo;

/**
 * XmlDriver is a metadata driver that enables mapping through XML files.
 *
 * @since       1.0
 * @author      Jonathan H. Wage <jonwage@gmail.com>
 * @author      Roman Borschel <roman@code-factory.org>
 */
class XmlDriver extends FileDriver
{
    const DEFAULT_FILE_EXTENSION = ".dcm.xml";

    /**
     * {@inheritDoc}
     */
    public function __construct(locator, fileExtension = self::DEFAULT_FILE_EXTENSION)
    {
        parent::__construct(locator, fileExtension);
    }

    /**
     * {@inheritDoc}
     */
    public function loadMetadataForClass(className, class1)
    {
        var xmlRoot, inheritanceType, discrField, map, discrMapElement, index, field, mapping, attributes,
            key, value, booleanAttributes, generatorOptions, attributesGenerator, embed, reference, lifecycleCallback, name;

        /* @var class ClassMetadataInfo */
        /* @var xmlRoot \SimpleXMLElement */
        let xmlRoot = this->getElement(className);
        if  ! xmlRoot {
            return;
        }

        if xmlRoot->getName() == "document" {
            if isset xmlRoot["repository-class"] {
                class1->setCustomRepositoryClass((string) xmlRoot["repository-class"]);
            }
        } else {
            if xmlRoot->getName() == "mapped-superclass" {
                class1->setCustomRepositoryClass(
                    isset xmlRoot["repository-class"] ? (string) xmlRoot["repository-class"] : null
                );
                let class1->isMappedSuperclass = true;
            } else {
                if xmlRoot->getName() == "embedded-document" {
                    let class1->isEmbeddedDocument = true;
                }
            }
        }
        if isset xmlRoot["db"] {
            class1->setDatabase((string) xmlRoot["db"]);
        }
        if isset xmlRoot["collection"] {
            class1->setCollection((string) xmlRoot["collection"]);
        }
        if isset xmlRoot["inheritance-type"] {
            let inheritanceType = (string) xmlRoot["inheritance-type"];
            class1->setInheritanceType(constant("Doctrine\ODM\MongoDB\Mapping\ClassMetadataInfo::INHERITANCE_TYPE_" . inheritanceType));
        }
        if isset xmlRoot["change-tracking-policy"] {
            class1->setChangeTrackingPolicy(constant("Doctrine\ODM\MongoDB\Mapping\ClassMetadataInfo::CHANGETRACKING_" . strtoupper((string) xmlRoot["change-tracking-policy"])));
        }
        if isset xmlRoot->{"discriminator-field"} {
            let discrField = xmlRoot->{"discriminator-field"};
            /* XSD only allows for "name", which is consistent with association
             * configurations, but fall back to "fieldName" for BC.
             */
            class1->setDiscriminatorField(
                isset discrField["name"] ? (string) discrField["name"] : (string) discrField["fieldName"]
            );
        }
        if isset xmlRoot->{"discriminator-map"} {
            let map = [];
            for discrMapElement in xmlRoot->{"discriminator-map"}->{"discriminator-mapping"} {
                let map[(string) discrMapElement["value"]] = (string) discrMapElement["class"];
            }
            class1->setDiscriminatorMap(map);
        }
        if isset xmlRoot->{"indexes"} {
            for index in xmlRoot->{"indexes"}->{"index"} {
                this->addIndex(class1, index);
            }
        }
        if isset xmlRoot->{"require-indexes"} {
            class1->setRequireIndexes((boolean) xmlRoot->{"require-indexes"});
        }
        if isset xmlRoot->{"slave-okay"} {
            class1->setSlaveOkay((boolean) xmlRoot->{"slave-okay"});
        }
        if isset xmlRoot->field {
            for field in xmlRoot->field {
                let mapping = [];
                let attributes = field->attributes();
                for key, value in attributes {
                    let mapping[key] = (string) value;
                    let booleanAttributes = ["id", "reference", "embed", "unique", "sparse", "file", "distance"];
                    if in_array(key, booleanAttributes) {
                        let mapping[key] = true == mapping[key] ? true : false;
                    }
                }
                if isset mapping["id"] && mapping["id"] === true && isset mapping["strategy"] {
                    let mapping["options"] = [];
                    if isset field->{"id-generator-option"} {
                        for generatorOptions in field->{"id-generator-option"} {
                            let attributesGenerator = iterator_to_array(generatorOptions->attributes());
                            if isset attributesGenerator["name"] && isset attributesGenerator["value"] {
                                let mapping["options"][(string) attributesGenerator["name"]] = (string) attributesGenerator["value"];
                            }
                        }
                    }
                } 
                
                if isset attributes["not-saved"] {
                    let mapping["notSaved"] = (true == attributes["not-saved"]) ? true : false;
                }
                if isset attributes["also-load"] {
                    let mapping["alsoLoadFields"] = explode(",", attributes["also-load"]);
                }
                this->addFieldMapping(class1, mapping);
            }
        }
        if isset xmlRoot->{"embed-one"} {
            for embed in xmlRoot->{"embed-one"} {
                this->addEmbedMapping(class1, embed, "one");
            }
        }
        if isset xmlRoot->{"embed-many"} {
            for embed in xmlRoot->{"embed-many"} {
                this->addEmbedMapping(class1, embed, "many");
            }
        }
        if isset xmlRoot->{"reference-many"} {
            for reference in xmlRoot->{"reference-many"} {
                this->addReferenceMapping(class1, reference, "many");
            }
        }
        if isset xmlRoot->{"reference-one"} {
            for reference in xmlRoot->{"reference-one"} {
                this->addReferenceMapping(class1, reference, "one");
            }
        }
        if isset xmlRoot->{"lifecycle-callbacks"} {
            for lifecycleCallback in xmlRoot->{"lifecycle-callbacks"}->{"lifecycle-callback"} {
                class1->addLifecycleCallback((string) lifecycleCallback["method"], constant("Doctrine\ODM\MongoDB\Events::" . (string) lifecycleCallback["type"]));
            }
        }
    }

    private function addFieldMapping( class1, mapping)
    {
        var name, a, keys, options, cascade;

        if isset mapping["name"] {
            let name = mapping["name"];
        } else {
            if isset mapping["fieldName"] {
                let name = mapping["fieldName"];
            } else {
                throw new \InvalidArgumentException("Cannot infer a MongoDB name from the mapping");
            }
        }

        if isset mapping["type"] && mapping["type"] === "collection" {
            // Note: this strategy is not actually used
            let mapping["strategy"] = isset mapping["strategy"] ? mapping["strategy"] : "pushAll";
        }

        class1->mapField(mapping);

        // Index this field if either "index", "unique", or "sparse" are set
        if  ! isset mapping["index"] || isset mapping["unique"] || isset mapping["sparse"] {
            return;
        }

        let a = isset mapping["order"] ? mapping["order"] : "asc";
        let keys = [name : a];
        let options = [];

        if isset mapping["background"] {
            let options["background"] = (boolean) mapping["background"];
        }
        if isset mapping["drop-dups"] {
            let options["dropDups"] = (boolean) mapping["drop-dups"];
        }
        if isset mapping["index-name"] {
            let options["name"] = (string) mapping["index-name"];
        }
        if isset mapping["safe"] {
            let options["safe"] = (boolean) mapping["safe"];
        }
        if isset mapping["sparse"] {
            let options["sparse"] = (boolean) mapping["sparse"];
        }
        if isset mapping["unique"] {
            let options["unique"] = (boolean) mapping["unique"];
        }

        class1->addIndex(keys, options);
    }

    private function addEmbedMapping( class1, embed, type)
    {
        var cascade, attributes, mapping, attr, discriminatorMapping;

        let cascade = array_keys(embed->cascade);
        if 1 === count(cascade) {
            let cascade = current(cascade) ? "" : next(cascade);
        }
        let attributes = embed->attributes();
        let mapping = [
            "type"           : type,
            "embedded"       : true,
            "targetDocument" : isset attributes["target-document"] ? (string) attributes["target-document"] : null,
            "name"           : (string) attributes["field"],
            "strategy"       : isset attributes["strategy"] ? (string) attributes["strategy"] : "pushAll"
        ];
        if isset attributes["fieldName"] {
            let mapping["fieldName"] = (string) attributes["fieldName"];
        }
        if isset embed->{"discriminator-field"} {
            let attr = embed->{"discriminator-field"};
            let mapping["discriminatorField"] = (string) attr["name"];
        }
        if isset embed->{"discriminator-map"} {
            for discriminatorMapping in embed->{"discriminator-map"}->{"discriminator-mapping"} {
                let attr = discriminatorMapping->attributes();
                let mapping["discriminatorMap"][(string) attr["value"]] = (string) attr["class"];
            }
        }
        if isset attributes["not-saved"] {
            let mapping["notSaved"] = (true == attributes["not-saved"]) ? true : false;
        }
        if isset attributes["also-load"] {
            let mapping["alsoLoadFields"] = explode(",", attributes["also-load"]);
        }
        this->addFieldMapping(class1, mapping);
    }

    private function addReferenceMapping( class1, reference, type)
    {
        var cascade, attributes, mapping, attr, discriminatorMapping, sort, criteria;

        let cascade = array_keys(reference->cascade);
        if 1 === count(cascade) {
            let cascade = current(cascade) ? "" : next(cascade);
        }
        let attributes = reference->attributes();
        let mapping = [
            "cascade"          : cascade,
            "orphanRemoval"    : isset attributes["orphan-removal"] ? reference["orphan-removal"] : false,
            "type"             : type,
            "reference"        : true,
            "simple"           : isset attributes["simple"] ? (boolean) attributes["simple"] : false,
            "targetDocument"   : isset attributes["target-document"] ? (string) attributes["target-document"] : null,
            "name"             : (string) attributes["field"],
            "strategy"         : isset attributes["strategy"] ? (string) attributes["strategy"] : "pushAll",
            "inversedBy"       : isset attributes["inversed-by"] ? (string) attributes["inversed-by"] : null,
            "mappedBy"         : isset attributes["mapped-by"] ? (string) attributes["mapped-by"] : null,
            "repositoryMethod" : isset attributes["repository-method"] ? (string) attributes["repository-method"] : null,
            "limit"            : isset attributes["limit"] ? (int) attributes["limit"] : null,
            "skip"             : isset attributes["skip"] ? (int) attributes["skip"] : null
        ];

        if isset attributes["fieldName"] {
            let mapping["fieldName"] = (string) attributes["fieldName"];
        }
        if isset reference->{"discriminator-field"} {
            let attr = reference->{"discriminator-field"};
            let mapping["discriminatorField"] = (string) attr["name"];
        }
        if isset reference->{"discriminator-map"} {
            for discriminatorMapping in reference->{"discriminator-map"}->{"discriminator-mapping"} {
                let attr = discriminatorMapping->attributes();
                let mapping["discriminatorMap"][(string) attr["value"]] = (string) attr["class"];
            }
        }
        if isset reference->{"sort"} {
            for sort in reference->{"sort"}->{"sort"} {
                let attr = sort->attributes();
                let mapping["sort"][(string) attr["field"]] = isset attr["order"] ? (string) attr["order"] : "asc";
            }
        }
        if isset reference->{"criteria"} {
            for criteria in reference->{"criteria"}->{"criteria"} {
                let attr = criteria->attributes();
                let mapping["criteria"][(string) attr["field"]] = (string) attr["value"];
            }
        }
        if isset attributes["not-saved"] {
            let mapping["notSaved"] = (true == attributes["not-saved"]) ? true : false;
        }
        if isset attributes["also-load"] {
            let mapping["alsoLoadFields"] = explode(",", attributes["also-load"]);
        }
        this->addFieldMapping(class1, mapping);
    }

    private function addIndex( class1, xmlIndex)
    {
        var attributes, keys, key, options, option, value;

        let attributes = xmlIndex->attributes();

        let keys = [];

        for key in xmlIndex->{"key"} {
            let keys[(string) key["name"]] = isset key["order"] ? (string) key["order"] : "asc";
        }

        let options = [];

        if isset attributes["background"] {
            let options["background"] = (true == attributes["background"]);
        }
        if isset attributes["drop-dups"] {
            let options["dropDups"] = (true == attributes["drop-dups"]);
        }
        if isset attributes["name"] {
            let options["name"] = (string) attributes["name"];
        }
        if isset attributes["safe"] {
            let options["safe"] = (true == attributes["safe"]);
        }
        if isset attributes["sparse"] {
            let options["sparse"] = (true == attributes["sparse"]);
        }
        if isset attributes["unique"] {
            let options["unique"] = (true == attributes["unique"]);
        }

        if isset xmlIndex->{"option"} {
            for option in xmlIndex->{"option"} {
                let value = (string) option["value"];
                if value === "true" {
                    let value = true;
                } else {
                    if value === "false" {
                        let value = false;
                    } else {
                        if is_numeric(value) {
                            let value = preg_match("/^[-]?\d+/", value) ? (int) value : (float) value;
                        }
                    }
                }
                let options[(string) option["name"]] = value;
            }
        }

        class1->addIndex(keys, options);
    }

    /**
     * {@inheritDoc}
     */
    protected function loadMappingFile(file)
    {
        var result, xmlElement, type, documentName, documentElement;

        let result = [];
        let xmlElement = simplexml_load_file(file);

        for type in ["document", "embedded-document", "mapped-superclass"] {
            if isset xmlElement->type {
                for documentElement in xmlElement->type {
                    let documentName = (string) documentElement["name"];
                    let result[documentName] = documentElement;
                }
            }
        }

        return result;
    }
}