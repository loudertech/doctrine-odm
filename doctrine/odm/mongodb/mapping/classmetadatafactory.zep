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

namespace Doctrine\ODM\MongoDB\Mapping;

use Doctrine\Common\Persistence\Mapping\AbstractClassMetadataFactory;
use Doctrine\Common\Persistence\Mapping\ClassMetadata as ClassMetadataInterface;
use Doctrine\Common\Persistence\Mapping\ReflectionService;
use Doctrine\ODM\MongoDB\Configuration;
use Doctrine\ODM\MongoDB\DocumentManager;
use Doctrine\ODM\MongoDB\Events;
use Doctrine\ODM\MongoDB\Mapping\ClassMetadata;
use Doctrine\ODM\MongoDB\Mapping\MappingException;

/**
 * The ClassMetadataFactory is used to create ClassMetadata objects that contain all the
 * metadata mapping informations of a class which describes how a class should be mapped
 * to a document database.
 *
 * @since       1.0
 * @author      Jonathan H. Wage <jonwage@gmail.com>
 * @author      Roman Borschel <roman@code-factory.org>
 */
class ClassMetadataFactory extends AbstractClassMetadataFactory
{
    protected cacheSalt = "\\MONGODBODMCLASSMETADATA";

    /** @var DocumentManager The DocumentManager instance */
    private dm;

    /** @var Configuration The Configuration instance */
    private config;

    /** @var \Doctrine\Common\Persistence\Mapping\Driver\MappingDriver The used metadata driver. */
    private driver;

    /** @var \Doctrine\Common\EventManager The event manager instance */
    private evm;

    /**
     * Sets the DocumentManager instance for this class.
     *
     * @param DocumentManager dm The DocumentManager instance
     */
    public function setDocumentManager(<DocumentManager> dm)
    {
        let this->dm = dm;
    }

    /**
     * Sets the Configuration instance
     *
     * @param Configuration config
     */
    public function setConfiguration(<Configuration> config)
    {
        let this->config = config;
    }

    /**
     * Lazy initialization of this stuff, especially the metadata driver,
     * since these are not needed at all when a metadata cache is active.
     */
    protected function initialize()
    {
        let this->driver = this->config->getMetadataDriverImpl();
        let this->evm = this->dm->getEventManager();
        let this->initialized = true;
    }

    /**
     * {@inheritDoc}
     */
    protected function getFqcnFromAlias(namespaceAlias, simpleClassName)
    {
        return this->config->getDocumentNamespace(namespaceAlias) . "\\" . simpleClassName;
    }

    /**
     * {@inheritDoc}
     */
    protected function getDriver()
    {
        return this->driver;
    }

    /**
     * {@inheritDoc}
     */
    protected function wakeupReflection(<ClassMetadataInterface> class1, <ReflectionService> reflService)
    {
    }

    /**
     * {@inheritDoc}
     */
    protected function initializeReflection(<ClassMetadataInterface> class1, <ReflectionService> reflService)
    {
    }

    /**
     * {@inheritDoc}
     */
    protected function isEntity(<ClassMetadataInterface> class1)
    {
        return !( class1->isMappedSuperclass) && ! (class1->isEmbeddedDocument);
    }

    /**
     * {@inheritDoc}
     */
    protected function doLoadMetadata(class1, parent, rootEntityFound, array nonSuperclassParents = [])
    {
        var eventArgs;

        /** @var class ClassMetadata */
        /** @var parent ClassMetadata */
        if parent {
            class1->setInheritanceType(parent->inheritanceType);
            class1->setDiscriminatorField(parent->discriminatorField);
            class1->setDiscriminatorMap(parent->discriminatorMap);
            class1->setIdGeneratorType(parent->generatorType);
            this->addInheritedFields(class1, parent);
            this->addInheritedIndexes(class1, parent);
            class1->setIdentifier(parent->identifier);
            class1->setVersioned(parent->isVersioned);
            class1->setVersionField(parent->versionField);
            class1->setLifecycleCallbacks(parent->lifecycleCallbacks);
            class1->setAlsoLoadMethods(parent->alsoLoadMethods);
            class1->setChangeTrackingPolicy(parent->changeTrackingPolicy);
            class1->setFile(parent->getFile());
            if parent->isMappedSuperclass {
                class1->setCustomRepositoryClass(parent->customRepositoryClassName);
            }
        }

        // Invoke driver
        //try {
            this->driver->loadMetadataForClass(class1->getName(), class1);
        /*} catch (\ReflectionException e) {
            throw MappingException::reflectionFailure(class1->getName(), e);
        }*/

        this->validateIdentifier(class1);

        if !empty parent && !empty rootEntityFound {
            if parent->generatorType {
                class1->setIdGeneratorType(parent->generatorType);
            }
            if parent->generatorOptions {
                class1->setIdGeneratorOptions(parent->generatorOptions);
            }
            if parent->idGenerator {
                class1->setIdGenerator(parent->idGenerator);
            }
        } else {
            this->completeIdGeneratorMapping(class1);
        }

        if parent && parent->isInheritanceTypeSingleCollection() {
            class1->setDatabase(parent->getDatabase());
            class1->setCollection(parent->getCollection());
        }

        class1->setParentClasses(nonSuperclassParents);

        if this->evm->hasListeners("loadClassMetadata") {
            let eventArgs = new \Doctrine\ODM\MongoDB\Event\LoadClassMetadataEventArgs(class1, this->dm);
            this->evm->dispatchEvent("loadClassMetadata", eventArgs);
        }
    }

    /**
     * Validates the identifier mapping.
     *
     * @param ClassMetadata class
     * @throws MappingException
     */
    protected function validateIdentifier(class1)
    {
        var x;

        if  ! class1->identifier && ! class1->isMappedSuperclass && ! class1->isEmbeddedDocument {
            let x = "MappingException";
            throw {x}::identifierRequired(class1->name);
        }
    }

    /**
     * Creates a new ClassMetadata instance for the given class name.
     *
     * @param string className
     * @return \Doctrine\ODM\MongoDB\Mapping\ClassMetadata
     */
    protected function newClassMetadataInstance(className)
    {
        return new ClassMetadata(className);
    }

    private function completeIdGeneratorMapping(<ClassMetadataInfo> class1)
    {
        var idGenOptions, incrementGenerator, uuidGenerator, alnumGenerator, customGenerator, methods,
            name, value, method, x;

        let idGenOptions = class1->generatorOptions;
        switch class1->generatorType {

            case 1://ClassMetadata::GENERATOR_TYPE_AUTO:
                class1->setIdGenerator(new \Doctrine\ODM\MongoDB\Id\AutoGenerator(class1));
                break;

            case 2://ClassMetadata::GENERATOR_TYPE_INCREMENT:
                let incrementGenerator = new \Doctrine\ODM\MongoDB\Id\IncrementGenerator(class1);
                if isset idGenOptions["key"] {
                    incrementGenerator->setKey(idGenOptions["key"]);
                }
                if isset idGenOptions["collection"] {
                    incrementGenerator->setCollection(idGenOptions["collection"]);
                }
                class1->setIdGenerator(incrementGenerator);
                break;

            case 3://ClassMetadata::GENERATOR_TYPE_UUID:
                let uuidGenerator = new \Doctrine\ODM\MongoDB\Id\UuidGenerator(class1);
                if isset idGenOptions["salt"] {
                    uuidGenerator->setSalt(idGenOptions["salt"]);
                }
                class1->setIdGenerator(uuidGenerator);
                break;

            case 4://ClassMetadata::GENERATOR_TYPE_ALNUM:
                let alnumGenerator = new \Doctrine\ODM\MongoDB\Id\AlnumGenerator(class1);
                if isset idGenOptions["pad"] {
                    alnumGenerator->setPad(idGenOptions["pad"]);
                }
                if isset idGenOptions["chars"] {
                    alnumGenerator->setChars(idGenOptions["chars"]);
                } else {
                    if isset idGenOptions["awkwardSafe"] {
                        alnumGenerator->setAwkwardSafeMode(idGenOptions["awkwardSafe"]);
                    }
                }
                class1->setIdGenerator(alnumGenerator);
                break;

            case 5://ClassMetadata::GENERATOR_TYPE_CUSTOM:
                if empty idGenOptions["class"] {
                    let x = "MappingException";
                    throw {x}::missingIdGeneratorClass(class1->name);
                }

                let x = idGenOptions["class"];
                let customGenerator = new {x}();
                unset(idGenOptions["class"]);
                if  ! (customGenerator instanceof \Doctrine\ODM\MongoDB\Id\AbstractIdGenerator) {
                    let x = "MappingException";
                    throw {x}::classIsNotAValidGenerator(get_class(customGenerator));
                }

                let methods = get_class_methods(customGenerator);
                for name, value in idGenOptions {
                    let method = "set" . ucfirst(name);
                    if  ! in_array(method, methods) {
                        let x = "MappingException";
                        throw {x}::missingGeneratorSetter(get_class(customGenerator), name);
                    }

                    customGenerator->method(value);
                }
                class1->setIdGenerator(customGenerator);
                break;
            case 6://ClassMetadata::GENERATOR_TYPE_NONE:
                break;
            default:
                throw new MappingException("Unknown generator type: " . class1->generatorType);
                break;
        }
    }

    /**
     * Adds inherited fields to the subclass mapping.
     *
     * @param ClassMetadata subClass
     * @param ClassMetadata parentClass
     */
    private function addInheritedFields(<ClassMetadata> subClass, <ClassMetadata> parentClass)
    {
        var fieldName, mapping, name, field;
        for fieldName, mapping in parentClass->fieldMappings {
            if  ! isset mapping["inherited"] && ! parentClass->isMappedSuperclass {
                let mapping["inherited"] = parentClass->name;
            }
            if  ! isset mapping["declared"] {
                let mapping["declared"] = parentClass->name;
            }
            subClass->addInheritedFieldMapping(mapping);
        }
        for name, field in parentClass->reflFields {
            let subClass->reflFields[name] = field;
        }
    }

    /**
     * Adds inherited indexes to the subclass mapping.
     *
     * @param ClassMetadata subClass
     * @param ClassMetadata parentClass
     */
    private function addInheritedIndexes(<ClassMetadata> subClass, <ClassMetadata> parentClass)
    {
        var index;
        for index in parentClass->indexes {
            subClass->addIndex(index["keys"], index["options"]);
        }
    }
}
