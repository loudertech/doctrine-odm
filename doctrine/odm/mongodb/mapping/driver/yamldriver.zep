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
use Symfony\Component\Yaml\Yaml;

/**
 * The YamlDriver reads the mapping metadata from yaml schema files.
 *
 * @since       1.0
 * @author      Jonathan H. Wage <jonwage@gmail.com>
 * @author      Roman Borschel <roman@code-factory.org>
 */
class YamlDriver extends FileDriver
{
    const DEFAULT_FILE_EXTENSION = ".dcm.yml";

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
    public function loadMetadataForClass(className,  class1)
    {
        var element, index, fieldName, mapping, type, embed, reference, methods, method, 
            name; 

        /* @var class ClassMetadataInfo */
        let element = this->getElement(className);
        if  ! element {
            return;
        }
        let element["type"] = isset element["type"] ? element["type"] : "document";

        if isset element["db"] {
            class1->setDatabase(element["db"]);
        }
        if isset element["collection"] {
            class1->setCollection(element["collection"]);
        }
        if element["type"] == "document" {
            if isset element["repositoryClass"] {
                class1->setCustomRepositoryClass(element["repositoryClass"]);
            }
        } else {
            if element["type"] === "mappedSuperclass" {
                class1->setCustomRepositoryClass(
                    isset element["repositoryClass"] ? element["repositoryClass"] : null
                );
                let class1->isMappedSuperclass = true;
            } else {
                if element["type"] === "embeddedDocument" {
                    let class1->isEmbeddedDocument = true;
                }
            }
        }
        if isset element["indexes"] {
            for index in element["indexes"] {
                class1->addIndex(index["keys"], isset index["options"] ? index["options"] : []);
            }
        }
        if isset element["inheritanceType"] {
            class1->setInheritanceType(constant("Doctrine\ODM\MongoDB\Mapping\ClassMetadata::INHERITANCE_TYPE_" . strtoupper(element["inheritanceType"])));
        }
        if isset element["discriminatorField"] {
            class1->setDiscriminatorField(this->parseDiscriminatorField(element["discriminatorField"]));
        }
        if isset element["discriminatorMap"] {
            class1->setDiscriminatorMap(element["discriminatorMap"]);
        }
        if isset element["changeTrackingPolicy"] {
            class1->setChangeTrackingPolicy(constant("Doctrine\ODM\MongoDB\Mapping\ClassMetadata::CHANGETRACKING_"
                    . strtoupper(element["changeTrackingPolicy"])));
        }
        if isset element["requireIndexes"] {
            class1->setRequireIndexes(element["requireIndexes"]);
        }
        if isset element["slaveOkay"] {
            class1->setSlaveOkay(element["slaveOkay"]);
        }
        if isset element["fields"] {
            for fieldName, mapping in element["fields"] {
                if typeof mapping == "string" {
                    let type = mapping;
                    let mapping = [];
                    let mapping["type"] = type;
                }
                if  !isset mapping["fieldName"] {
                    let mapping["fieldName"] = fieldName;
                }
                if isset mapping["type"] && mapping["type"] === "collection" {
                    // Note: this strategy is not actually used
                    let mapping["strategy"] = isset mapping["strategy"] ? mapping["strategy"] : "pushAll";
                }
                if isset mapping["type"] && ! empty mapping["embedded"] {
                    this->addMappingFromEmbed(class1, fieldName, mapping, mapping["type"]);
                } else {
                    if isset mapping["type"] && ! empty mapping["reference"] {
                        this->addMappingFromReference(class1, fieldName, mapping, mapping["type"]);
                    } else {
                        this->addFieldMapping(class1, mapping);
                    }
                }
            }
        }
        if isset element["embedOne"] {
            for fieldName, embed in element["embedOne"] {
                this->addMappingFromEmbed(class1, fieldName, embed, "one");
            }
        }
        if isset element["embedMany"] {
            for fieldName, embed in element["embedMany"] {
                this->addMappingFromEmbed(class1, fieldName, embed, "many");
            }
        }
        if isset element["referenceOne"] {
            for fieldName, reference in element["referenceOne"] {
                this->addMappingFromReference(class1, fieldName, reference, "one");
            }
        }
        if isset element["referenceMany"] {
            for fieldName, reference in element["referenceMany"] {
                this->addMappingFromReference(class1, fieldName, reference, "many");
            }
        }
        if isset element["lifecycleCallbacks"] {
            for type, methods in element["lifecycleCallbacks"] {
                for method in methods {
                    class1->addLifecycleCallback(method, constant("Doctrine\ODM\MongoDB\Events::" . type));
                }
            }
        }
    }

    private function addFieldMapping( class1, mapping)
    {
        var name, keys, options;

        if isset mapping["name"] {
            let name = mapping["name"];
        } else {
            if isset mapping["fieldName"] {
                let name = mapping["fieldName"];
            } else {
                throw new \InvalidArgumentException("Cannot infer a MongoDB name from the mapping");
            }
        }

        class1->mapField(mapping);

        if  !isset mapping["index"] || isset mapping["unique"] || isset mapping["sparse"] {
            return false;
        }

        // Index this field if either "index", "unique", or "sparse" are set
        //let keys = [ name : "asc" ];
        let keys = [];
        let keys[name] = "asc"; 


        if isset mapping["index"]["order"] {
            let keys[name] = mapping["index"]["order"];
            unset(mapping["index"]["order"]);
        } else {
            if isset mapping["unique"]["order"] {
                let keys[name] = mapping["unique"]["order"];
                unset(mapping["unique"]["order"]);
            } else {
                if isset mapping["sparse"]["order"] {
                    let keys[name] = mapping["sparse"]["order"];
                    unset(mapping["sparse"]["order"]);
                }
            }
        }

        let options = [];

        if isset mapping["index"] {
            let options = typeof mapping["index"] == "array" ? mapping["index"] : [];
        } else {
            if isset mapping["unique"] {
                let options = typeof mapping["unique"] == "array" ? mapping["unique"] : [];
                let options["unique"] = true;
            } else {
                if isset mapping["sparse"] {
                    let options = typeof mapping["sparse"] == "array" ? mapping["sparse"] : [];
                    let options["sparse"] = true;
                }
            }
        }

        class1->addIndex(keys, options);
    }

    private function addMappingFromEmbed( class1, fieldName, embed, type)
    {
        var mapping;

        let mapping = [
            "type"           : type,
            "embedded"       : true,
            "targetDocument" : isset embed["targetDocument"] ? embed["targetDocument"] : null,
            "fieldName"      : fieldName,
            "strategy"       : isset embed["strategy"] ? (string) embed["strategy"] : "pushAll"
        ];
        if isset embed["name"] {
            let mapping["name"] = embed["name"];
        }
        if isset embed["discriminatorField"] {
            let mapping["discriminatorField"] = this->parseDiscriminatorField(embed["discriminatorField"]);
        }
        if isset embed["discriminatorMap"] {
            let mapping["discriminatorMap"] = embed["discriminatorMap"];
        }
        this->addFieldMapping(class1, mapping);
    }

    private function addMappingFromReference( class1, fieldName, reference, type)
    {
        var mapping;

        let mapping = [
            "cascade"          : isset reference["cascade"] ? reference["cascade"] : null,
            "orphanRemoval"    : isset reference["orphanRemoval"] ? reference["orphanRemoval"] : false,
            "type"             : type,
            "reference"        : true,
            "simple"           : isset reference["simple"] ? (boolean) reference["simple"] : false,
            "targetDocument"   : isset reference["targetDocument"] ? reference["targetDocument"] : null,
            "fieldName"        : fieldName,
            "strategy"         : isset reference["strategy"] ? (string) reference["strategy"] : "pushAll",
            "inversedBy"       : isset reference["inversedBy"] ? (string) reference["inversedBy"] : null,
            "mappedBy"         : isset reference["mappedBy"] ? (string) reference["mappedBy"] : null,
            "repositoryMethod" : isset reference["repositoryMethod"] ? (string) reference["repositoryMethod"] : null,
            "limit"            : isset reference["limit"] ? (int) reference["limit"] : null,
            "skip"             : isset reference["skip"] ? (int) reference["skip"] : null
        ];
        if isset reference["name"] {
            let mapping["name"] = reference["name"];
        }
        if isset reference["discriminatorField"] {
            let mapping["discriminatorField"] = this->parseDiscriminatorField(reference["discriminatorField"]);
        }
        if isset reference["discriminatorMap"] {
            let mapping["discriminatorMap"] = reference["discriminatorMap"];
        }
        if isset reference["sort"] {
            let mapping["sort"] = reference["sort"];
        }
        if isset reference["criteria"] {
            let mapping["criteria"] = reference["criteria"];
        }
        this->addFieldMapping(class1, mapping);
    }

    /**
     * Parses the class or field-level "discriminatorField" option.
     *
     * If the value is an array, check the "name" option before falling back to
     * the deprecated "fieldName" option (for BC). Otherwise, the value must be
     * a string.
     *
     * @param array|string discriminatorField
     * @return string
     * @throws \InvalidArgumentException if the value is neither a string nor an
     *                                   array with a "name" or "fieldName" key.
     */
    private function parseDiscriminatorField(discriminatorField)
    {
        if typeof discriminatorField == "string" {
            return discriminatorField;
        }

        if  typeof discriminatorField != "array" {
            throw new \InvalidArgumentException("Expected array or string for discriminatorField; found: " . gettype(discriminatorField));
        }

        if isset discriminatorField["name"] {
            return (string) discriminatorField["name"];
        }

        if isset discriminatorField["fieldName"] {
            return (string) discriminatorField["fieldName"];
        }

        throw new \InvalidArgumentException("Expected 'name' or 'fieldName' key in discriminatorField array; found neither.");
    }

    /**
     * {@inheritDoc}
     */
    protected function loadMappingFile(file)
    {
        //return Yaml::parse(file);
    }
}