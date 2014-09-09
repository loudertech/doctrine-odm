
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

namespace Doctrine\ODM\MongoDB\Hydrator;

use Doctrine\Common\EventManager;
use Doctrine\ODM\MongoDB\DocumentManager;
use Doctrine\ODM\MongoDB\Event\LifecycleEventArgs;
use Doctrine\ODM\MongoDB\Event\PreLoadEventArgs;
use Doctrine\ODM\MongoDB\Events;
use Doctrine\ODM\MongoDB\Mapping\ClassMetadata;
use Doctrine\ODM\MongoDB\Proxy\Proxy;
use Doctrine\ODM\MongoDB\Types\Type;
use Doctrine\ODM\MongoDB\UnitOfWork;

/**
 * The HydratorFactory class is responsible for instantiating a correct hydrator
 * type based on document's ClassMetadata
 *
 * @since       1.0
 * @author      Jonathan H. Wage <jonwage@gmail.com>
 */
class HydratorFactory
{
    /**
     * The DocumentManager this factory is bound to.
     *
     * @var \Doctrine\ODM\MongoDB\DocumentManager
     */
    public dm;

    /**
     * The UnitOfWork used to coordinate object-level transactions.
     *
     * @var \Doctrine\ODM\MongoDB\UnitOfWork
     */
    public unitOfWork;

    /**
     * The EventManager associated with this Hydrator
     *
     * @var \Doctrine\Common\EventManager
     */
    public evm;

    /**
     * Whether to automatically (re)generate hydrator classes.
     *
     * @var boolean
     */
    public autoGenerate;

    /**
     * The namespace that contains all hydrator classes.
     *
     * @var string
     */
    public hydratorNamespace;

    /**
     * The directory that contains all hydrator classes.
     *
     * @var string
     */
    public hydratorDir;

    /**
     * Array of instantiated document hydrators.
     *
     * @var array
     */
    public hydrators;

    /**
     * @param DocumentManager $dm
     * @param EventManager $evm
     * @param string $hydratorDir
     * @param string $hydratorNs
     * @param boolean $autoGenerate
     * @throws HydratorException
     */
    public function __construct(dm, evm, hydratorDir, hydratorNs, autoGenerate)
    {
        if !hydratorDir {
            //throw HydratorException::hydratorDirectoryRequired();
            throw new \Exception("?");
        }
        if !hydratorNs {
            //throw HydratorException::hydratorNamespaceRequired();
            throw new \Exception("?");
        }
        let this->dm = dm,
            this->evm = evm,
            this->hydratorDir = hydratorDir,
            this->hydratorNamespace = hydratorNs,
            this->autoGenerate = autoGenerate,
            this->hydrators = [];
    }

    /**
     * Sets the UnitOfWork instance.
     *
     * @param UnitOfWork $uow
     */
    public function setUnitOfWork(uow)
    {
        let this->unitOfWork = uow;
    }

    /**
     * Gets the hydrator object for the given document class.
     *
     * @param string $className
     * @return \Doctrine\ODM\MongoDB\Hydrator\HydratorInterface $hydrator
     */
    public function getHydratorFor(className)
    {
        var hydrator, hydratorClassName, fileName, fqn, classInstance;

        if fetch hydrator, this->hydrators[className]  {
            return hydrator;
        }

        let hydratorClassName = str_replace("\\", "", className) . "Hydrator";

        let fqn = this->hydratorNamespace . "\\" . hydratorClassName,
            classInstance = this->dm->getClassMetadata(className);

        if !class_exists(fqn, false) {

            let fileName = this->hydratorDir . DIRECTORY_SEPARATOR . hydratorClassName . ".php";
            if this->autoGenerate {
                this->{"generateHydratorClass"}(classInstance, hydratorClassName, fileName);
            }
            require fileName;
        }

        let hydrator = new {fqn}(this->dm, this->unitOfWork, classInstance),
            this->hydrators[className] = hydrator;
        return hydrator;
    }

    /**
     * Generates hydrator classes for all given classes.
     *
     * @param array $classes The classes (ClassMetadata instances) for which to generate hydrators.
     * @param string $toDir The target directory of the hydrator classes. If not specified, the
     *                      directory configured on the Configuration of the DocumentManager used
     *                      by this factory is used.
     */
    public function generateHydratorClasses(array classes, toDir = null)
    {
        var hydratorDir, classInstance, hydratorClassName, hydratorFileName;

        let hydratorDir = toDir ? toDir : this->hydratorDir;
        let hydratorDir = rtrim(hydratorDir, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR;

        for classInstance in classes {
            let hydratorClassName = str_replace("\\", "", classInstance->name) . "Hydrator",
                hydratorFileName = hydratorDir . hydratorClassName . ".php";
            this->{"generateHydratorClass"}(classInstance, hydratorClassName, hydratorFileName);
        }
    }

    /**
     * Hydrate array of MongoDB document data into the given document object.
     *
     * @param object $document  The document object to hydrate the data into.
     * @param array $data The array of document data.
     * @param array $hints Any hints to account for during reconstitution/lookup of the document.
     * @return array $values The array of hydrated values.
     */
    public final function hydrate(document, data, array hints = [])
    {
        var metadata, alsoLoadMethods, method, fieldNames, fieldName;

        let metadata = this->dm->getClassMetadata(get_class(document));

        // Invoke preLoad lifecycle events and listeners
        //if !empty metadata->lifecycleCallbacks[Events::preLoad] {
        //    $args = array(&$data);
        //    $metadata->invokeLifecycleCallbacks(Events::preLoad, $document, $args);
        //}

        //if ($this->evm->hasListeners(Events::preLoad)) {
        //    $this->evm->dispatchEvent(Events::preLoad, new PreLoadEventArgs($document, $this->dm, $data));
        //}

        // alsoLoadMethods may transform the document before hydration
        let alsoLoadMethods = metadata->alsoLoadMethods;
        if !empty alsoLoadMethods {
            for method, fieldNames in alsoLoadMethods {
                for fieldName in fieldNames {
                    // Invoke the method only once for the first field we find
                    if array_key_exists(fieldName, data) {
                        document->{method}(data[fieldName]);
                        break;
                    }
                }
            }
        }

        let data = this->getHydratorFor(metadata->name)->hydrate(document, data, hints);
        if document instanceof Proxy {
            let document->__isInitialized__ = true;
        }

        // Invoke the postLoad lifecycle callbacks and listeners
        //if (!empty($metadata->lifecycleCallbacks[Events::postLoad])) {
        //    $metadata->invokeLifecycleCallbacks(Events::postLoad, $document);
        //}
        //if ($this->evm->hasListeners(Events::postLoad)) {
        //    $this->evm->dispatchEvent(Events::postLoad, new LifecycleEventArgs($document, $this->dm));
        //}

        return data;
    }
}
