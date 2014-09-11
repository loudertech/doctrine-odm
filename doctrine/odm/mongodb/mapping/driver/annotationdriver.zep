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

use Doctrine\Common\Annotations\AnnotationReader;
use Doctrine\Common\Annotations\AnnotationRegistry;
use Doctrine\Common\Annotations\Reader;
use Doctrine\Common\Persistence\Mapping\ClassMetadata;
use Doctrine\Common\Persistence\Mapping\Driver\AnnotationDriver as AbstractAnnotationDriver;
use Doctrine\ODM\MongoDB\Events;
use Doctrine\ODM\MongoDB\Mapping\Annotations;
use Doctrine\ODM\MongoDB\Mapping\ClassMetadataInfo;
use Doctrine\ODM\MongoDB\Mapping\MappingException;

/**
 * The AnnotationDriver reads the mapping metadata from docblock annotations.
 *
 * @since       1.0
 * @author      Jonathan H. Wage <jonwage@gmail.com>
 * @author      Roman Borschel <roman@code-factory.org>
 */
class AnnotationDriver extends AbstractAnnotationDriver
{
    protected entityAnnotationClasses = [
        "Doctrine\\ODM\\MongoDB\\Mapping\\Annotations\\Document": 1,
        "Doctrine\\ODM\\MongoDB\\Mapping\\Annotations\\MappedSuperclass": 2,
        "Doctrine\\ODM\\MongoDB\\Mapping\\Annotations\\EmbeddedDocument": 3
    ];

    /**
     * Registers annotation classes to the common registry.
     *
     * This method should be called when bootstrapping your application.
     */
    public static function registerAnnotationClasses()
    {
        //AnnotationRegistry::registerFile(__DIR__ . "/../Annotations/DoctrineAnnotations.php");
    }

    /**
     * {@inheritdoc}
     */
    public function loadMetadataForClass(className,  class1)
    {
        var reflClass, classAnnotations, documentAnnots, annot, documentAnnot, annotArr, annotClass, i, index,
            property, indexes, mapping, fieldAnnot, name, keys, method;

        /** @var class ClassMetadataInfo */
        let reflClass = class1->getReflectionClass();

        let classAnnotations = this->reader->getClassAnnotations(reflClass);

        let documentAnnots = [];
        for annot in classAnnotations {

            let classAnnotations[get_class(annot)] = annot;

            for annotClass, i in this->entityAnnotationClasses {
                if annot instanceof annotClass {
                    let documentAnnots[i] = annot;
                    continue;
                }
            }

            // non-document class annotations
            if annot instanceof Annotations\AbstractIndex {
                this->addIndex(class1, annot);
            }
            if annot instanceof Annotations\Indexes {
                let annotArr = typeof annot->value == "array" ? annot->value : [annot->value];
                for index in annotArr {
                    this->addIndex(class1, index);
                }
            } else {
                if annot instanceof Annotations\InheritanceType {
                    class1->setInheritanceType(constant("Doctrine\\ODM\\MongoDB\\Mapping\\ClassMetadata::INHERITANCE_TYPE_" . annot->value));
                } else {
                    if annot instanceof Annotations\DiscriminatorField {
                        // fieldName property is deprecated, but fall back for BC
                        if isset annot->value {
                            class1->setDiscriminatorField(annot->value);
                        } else {
                            if isset annot->name {
                                class1->setDiscriminatorField(annot->name);
                            } else {
                                if isset annot->fieldName {
                                    class1->setDiscriminatorField(annot->fieldName);
                                }
                            }
                        }
                    } else {
                        if annot instanceof Annotations\DiscriminatorMap {
                            class1->setDiscriminatorMap(annot->value);
                        } else {
                            if annot instanceof Annotations\DiscriminatorValue {
                                class1->setDiscriminatorValue(annot->value);
                            } else {
                                if annot instanceof Annotations\ChangeTrackingPolicy {
                                    class1->setChangeTrackingPolicy(constant("Doctrine\\ODM\\MongoDB\\Mapping\\ClassMetadata::CHANGETRACKING_" . annot->value));
                                }
                            }
                        }
                    }   
                }
            }
        }

        if !documentAnnots {
            throw MappingException::classIsNotAValidDocument(className);
        }

        // find the winning document annotation
        ksort(documentAnnots);
        let documentAnnot = reset(documentAnnots);

        if documentAnnot instanceof Annotations\MappedSuperclass {
            let class1->isMappedSuperclass = true;
        } else {
            if documentAnnot instanceof Annotations\EmbeddedDocument {
                let class1->isEmbeddedDocument = true;
            }
        }
        if isset documentAnnot->db {
            class1->setDatabase(documentAnnot->db);
        }
        if isset documentAnnot->collection {
            class1->setCollection(documentAnnot->collection);
        }
        if isset documentAnnot->repositoryClass {
            class1->setCustomRepositoryClass(documentAnnot->repositoryClass);
        }
        if isset documentAnnot->indexes {
            for index in documentAnnot->indexes {
                this->addIndex(class1, index);
            }
        }
        if isset documentAnnot->requireIndexes {
            class1->setRequireIndexes(documentAnnot->requireIndexes);
        }
        if isset documentAnnot->slaveOkay {
            class1->setSlaveOkay(documentAnnot->slaveOkay);
        }

        for property in reflClass->getProperties() {
            if (class1->isMappedSuperclass && ! property->isPrivate())
                ||
                (class1->isInheritedField(property->name) && property->getDeclaringClass()->name !== class1->name) {
                continue;
            }

            let indexes = [];
            let mapping = ["fieldName": property->getName()];
            let fieldAnnot = null;

            for annot in this->reader->getPropertyAnnotations(property) {
                if annot instanceof Annotations\AbstractField {
                    let fieldAnnot = annot;
                }
                if annot instanceof Annotations\AbstractIndex {
                    let indexes[] = annot;
                }
                if annot instanceof Annotations\Indexes {
                    let annotArr = typeof annot->value == "array" ? annot->value : [annot->value];
                    for index in annotArr {
                        let indexes[] = index;
                    }
                } else {
                    if annot instanceof Annotations\AlsoLoad {
                        let mapping["alsoLoadFields"] = annot->value;
                    } else {
                        if annot instanceof Annotations\Version {
                            let mapping["version"] = true;
                        } else {
                            if annot instanceof Annotations\Lock {
                                let mapping["lock"] = true;
                            }
                        }
                    }
                }
            }

            if fieldAnnot {
                let mapping = array_replace(mapping, fieldAnnot);
                class1->mapField(mapping);
            }

            if indexes {
                for index in indexes {
                    let name = isset mapping["name"] == true ? mapping["name"] : mapping["fieldName"];
                    let keys = [name : (index->order ? "" : "asc")];
                    this->addIndex(class1, index, keys);
                }
            }
        }

        /** @var method \ReflectionMethod */
        for method in reflClass->getMethods(\ReflectionMethod::IS_PUBLIC) {
            /* Filter for the declaring class only. Callbacks from parent
             * classes will already be registered.
             */
            if method->getDeclaringClass()->name !== reflClass->name {
                continue;
            }

            for annot in this->reader->getMethodAnnotations(method) {
                if annot instanceof Annotations\AlsoLoad {
                    class1->registerAlsoLoadMethod(method->getName(), annot->value);
                }

                if !isset classAnnotations["Doctrine\ODM\MongoDB\Mapping\Annotations\HasLifecycleCallbacks"] {
                    continue;
                }

                if annot instanceof Annotations\PrePersist {
                    class1->addLifecycleCallback(method->getName(), Events::PREPERSIST);
                } else {
                    if annot instanceof Annotations\PostPersist {
                        class1->addLifecycleCallback(method->getName(), Events::POSTPERSIST);
                    } else {
                        if annot instanceof Annotations\PreUpdate {
                            class1->addLifecycleCallback(method->getName(), Events::PREUPDATE);
                        } else {
                            if annot instanceof Annotations\PostUpdate {
                                class1->addLifecycleCallback(method->getName(), Events::POSTUPDATE);
                            } else {
                                if annot instanceof Annotations\PreRemove {
                                    class1->addLifecycleCallback(method->getName(), Events::PREREMOVE);
                                } else {
                                    if annot instanceof Annotations\PostRemove {
                                        class1->addLifecycleCallback(method->getName(), Events::POSTREMOVE);
                                    } else {
                                        if annot instanceof Annotations\PreLoad {
                                            class1->addLifecycleCallback(method->getName(), Events::PRELOAD);
                                        } else {
                                            if annot instanceof Annotations\PostLoad {
                                                class1->addLifecycleCallback(method->getName(), Events::POSTLOAD);
                                            } else {
                                                if annot instanceof Annotations\PreFlush {
                                                    class1->addLifecycleCallback(method->getName(), Events::PREFLUSH);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private function addIndex( class1, index, array keys = [])
    {
        var options, allowed, name;
        let keys = array_merge(keys, index->keys);
        let options = [];
        let allowed = ["name", "dropDups", "background", "safe", "unique", "sparse", "expireAfterSeconds"];
        for name in allowed {
            if isset index->name {
                let options[name] = index->name;
            }
        }
        let options = array_merge(options, index->options);
        class1->addIndex(keys, options);
    }

    /**
     * Factory method for the Annotation Driver
     *
     * @param array|string paths
     * @param Reader reader
     * @return AnnotationDriver
     */
    public static function create(paths = [],  reader = null)
    {
        if reader === null {
            let reader = new AnnotationReader();
        }
        return new self(reader, paths);
    }
}