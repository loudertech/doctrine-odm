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

namespace Doctrine\Common\Persistence\Mapping;

use Doctrine\Common\Cache\Cache;
use Doctrine\Common\Util\ClassUtils;

/**
 * The ClassMetadataFactory is used to create ClassMetadata objects that contain all the
 * metadata mapping informations of a class which describes how a class should be mapped
 * to a relational database.
 *
 * This class was abstracted from the ORM ClassMetadataFactory.
 *
 * @since  2.2
 * @author Benjamin Eberlei <kontakt@beberlei.de>
 * @author Guilherme Blanco <guilhermeblanco@hotmail.com>
 * @author Jonathan Wage <jonwage@gmail.com>
 * @author Roman Borschel <roman@code-factory.org>
 */
abstract class AbstractClassMetadataFactory implements ClassMetadataFactory
{
    /**
     * Salt used by specific Object Manager implementation.
     *
     * @var string
     */
    protected cacheSalt = "CLASSMETADATA";

    /**
     * @var \Doctrine\Common\Cache\Cache|null
     */
    private cacheDriver;

    /**
     * @var array
     */
    private loadedMetadata = [];

    /**
     * @var bool
     */
    protected initialized = false;

    /**
     * @var ReflectionService|null
     */
    private reflectionService = null;

    /**
     * Sets the cache driver used by the factory to cache ClassMetadata instances.
     *
     * @param \Doctrine\Common\Cache\Cache cacheDriver
     *
     * @return void
     */
    public function setCacheDriver(<Cache> cacheDriver = null)
    {
        let this->cacheDriver = cacheDriver;
    }

    /**
     * Gets the cache driver used by the factory to cache ClassMetadata instances.
     *
     * @return \Doctrine\Common\Cache\Cache|null
     */
    public function getCacheDriver()
    {
        return this->cacheDriver;
    }

    /**
     * Returns an array of all the loaded metadata currently in memory.
     *
     * @return array
     */
    public function getLoadedMetadata()
    {
        return this->loadedMetadata;
    }

    /**
     * Forces the factory to load the metadata of all classes known to the underlying
     * mapping driver.
     *
     * @return array The ClassMetadata instances of all mapped classes.
     */
    public function getAllMetadata()
    {
        var driver, metadata, className;

        if  !this->initialized {
            this->initialize();
        }

        let driver = this->getDriver();
        let metadata = [];
        for className in driver->getAllClassNames() {
            let metadata[] = this->getMetadataFor(className);
        }

        return metadata;
    }

    /**
     * Lazy initialization of this stuff, especially the metadata driver,
     * since these are not needed at all when a metadata cache is active.
     *
     * @return void
     */
    abstract protected function initialize();

    /**
     * Gets the fully qualified class-name from the namespace alias.
     *
     * @param string namespaceAlias
     * @param string simpleClassName
     *
     * @return string
     */
    abstract protected function getFqcnFromAlias(namespaceAlias, simpleClassName);

    /**
     * Returns the mapping driver implementation.
     *
     * @return \Doctrine\Common\Persistence\Mapping\Driver\MappingDriver
     */
    abstract protected function getDriver();

    /**
     * Wakes up reflection after ClassMetadata gets unserialized from cache.
     *
     * @param ClassMetadata     class
     * @param ReflectionService reflService
     *
     * @return void
     */
    abstract protected function wakeupReflection(<ClassMetadata> class1, <ReflectionService> reflService);

    /**
     * Initializes Reflection after ClassMetadata was constructed.
     *
     * @param ClassMetadata     class
     * @param ReflectionService reflService
     *
     * @return void
     */
    abstract protected function initializeReflection(<ClassMetadata> class1, <ReflectionService> reflService);

    /**
     * Checks whether the class metadata is an entity.
     *
     * This method should return false for mapped superclasses or embedded classes.
     *
     * @param ClassMetadata class
     *
     * @return boolean
     */
    abstract protected function isEntity(<ClassMetadata> class1);

    /**
     * Gets the class metadata descriptor for a class.
     *
     * @param string className The name of the class.
     *
     * @return \Doctrine\Common\Persistence\Mapping\ClassMetadata
     */
    public function getMetadataFor(className)
    {
        var realClassName, list, namespaceAlias, simpleClassName, cached, loadedClassName;

        if isset this->loadedMetadata[className] {
            return this->loadedMetadata[className];
        }

        let realClassName = className;

        // Check for namespace alias
        if strpos(className, ":") !== false {
            let list = explode(":", className);
            let namespaceAlias = list[0];
            let simpleClassName = list[1];
            let realClassName = this->getFqcnFromAlias(namespaceAlias, simpleClassName);
        } else {
            let realClassName = ClassUtils::getRealClass(realClassName);
        }

        if isset this->loadedMetadata[realClassName] {
            // We do not have the alias name in the map, include it
            let this->loadedMetadata[className] = this->loadedMetadata[realClassName];

            return this->loadedMetadata[realClassName];
        }

        if this->cacheDriver {
            let cached = this->cacheDriver->{"fetch"}(realClassName . this->cacheSalt);
            if cached !== false {
                let this->loadedMetadata[realClassName] = cached;
                this->wakeupReflection(cached, this->getReflectionService());
            } else {
                for loadedClassName in this->loadMetadata(realClassName) {
                    this->cacheDriver->save(
                        loadedClassName . this->cacheSalt, this->loadedMetadata[loadedClassName], null
                    );
                }
            }
        } else {
            this->loadMetadata(realClassName);
        }

        if className != realClassName {
            // We do not have the alias name in the map, include it
            let this->loadedMetadata[className] = this->loadedMetadata[realClassName];
        }

        return this->loadedMetadata[className];
    }

    /**
     * Checks whether the factory has the metadata for a class loaded already.
     *
     * @param string className
     *
     * @return boolean TRUE if the metadata of the class in question is already loaded, FALSE otherwise.
     */
    public function hasMetadataFor(className)
    {
        return isset this->loadedMetadata[className];
    }

    /**
     * Sets the metadata descriptor for a specific class.
     *
     * NOTE: This is only useful in very special cases, like when generating proxy classes.
     *
     * @param string        className
     * @param ClassMetadata class
     *
     * @return void
     */
    public function setMetadataFor(className, class1)
    {
        let this->loadedMetadata[className] = class1;
    }

    /**
     * Gets an array of parent classes for the given entity class.
     *
     * @param string name
     *
     * @return array
     */
    protected function getParentClasses(name)
    {
        var parentClasses, parentClass;

        // Collect parent classes, ignoring transient (not-mapped) classes.
        let parentClasses = [];
        for parentClass in array_reverse(this->getReflectionService()->getParentClasses(name)) {
            if  !this->getDriver()->isTransient(parentClass) {
                let parentClasses[] = parentClass;
            }
        }
        return parentClasses;
    }

    /**
     * Loads the metadata of the class in question and all it"s ancestors whose metadata
     * is still not loaded.
     *
     * Important: The class name does not necesarily exist at this point here.
     * Scenarios in a code-generation setup might have access to XML/YAML
     * Mapping files without the actual PHP code existing here. That is why the
     * {@see Doctrine\Common\Persistence\Mapping\ReflectionService} interface
     * should be used for reflection.
     *
     * @param string name The name of the class for which the metadata should get loaded.
     *
     * @return array
     */
    protected function loadMetadata(name)
    {
        var loaded, parentClasses, parent, rootEntityFound, visited, reflService, className,
            class1;

        if  ! this->initialized {
            this->initialize();
        }

        let loaded = [];

        let parentClasses = this->getParentClasses(name);
        let parentClasses[] = name;

        // Move down the hierarchy of parent classes, starting from the topmost class
        let parent = null;
        let rootEntityFound = false;
        let visited = [];
        let reflService = this->getReflectionService();
        for className in parentClasses {
            if isset this->loadedMetadata[className] {
                let parent = this->loadedMetadata[className];
                if this->isEntity(parent) {
                    let rootEntityFound = true;
                    array_unshift(visited, className);
                }
                continue;
            }

            let class1 = this->newClassMetadataInstance(className);
            this->initializeReflection(class1, reflService);

            this->doLoadMetadata(class1, parent, rootEntityFound, visited);

            let this->loadedMetadata[className] = class1;

            let parent = class1;

            if this->isEntity(class1) {
                let rootEntityFound = true;
                array_unshift(visited, className);
            }

            this->wakeupReflection(class1, reflService);

            let loaded[] = className;
        }

        return loaded;
    }

    /**
     * Actually loads the metadata from the underlying metadata.
     *
     * @param ClassMetadata      class
     * @param ClassMetadata|null parent
     * @param bool               rootEntityFound
     * @param array              nonSuperclassParents All parent class names
     *                                                 that are not marked as mapped superclasses.
     *
     * @return void
     */
    abstract protected function doLoadMetadata(class1, parent, rootEntityFound, array nonSuperclassParents);

    /**
     * Creates a new ClassMetadata instance for the given class name.
     *
     * @param string className
     *
     * @return ClassMetadata
     */
    abstract protected function newClassMetadataInstance(className);

    /**
     * {@inheritDoc}
     */
    public function isTransient(class1)
    {
        var list, namespaceAlias, simpleClassName;

        if  ! this->initialized {
            this->initialize();
        }

        // Check for namespace alias
        if strpos(class1, ":") !== false {
            let list = explode(":", class1);
            let namespaceAlias = list[0];
            let simpleClassName = list[1];
            let class1 = this->getFqcnFromAlias(namespaceAlias, simpleClassName);
        }

        return this->getDriver()->isTransient(class1);
    }

    /**
     * Sets the reflectionService.
     *
     * @param ReflectionService reflectionService
     *
     * @return void
     */
    public function setReflectionService(<ReflectionService> reflectionService)
    {
        let this->reflectionService = reflectionService;
    }

    /**
     * Gets the reflection service associated with this metadata factory.
     *
     * @return ReflectionService
     */
    public function getReflectionService()
    {
        if this->reflectionService === null {
            let this->reflectionService = new RuntimeReflectionService();
        }
        return this->reflectionService;
    }
}
