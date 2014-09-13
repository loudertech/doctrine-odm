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

use Doctrine\ODM\MongoDB\LockException;
use Doctrine\ODM\MongoDB\Mapping\MappingException;
use Doctrine\ODM\MongoDB\Proxy\Proxy;
use Doctrine\ODM\MongoDB\Types\Type;
use Doctrine\ODM\MongoDB\Mapping\ClassMetadataInfo;
use InvalidArgumentException;

/**
 * A <tt>ClassMetadata</tt> instance holds all the object-document mapping metadata
 * of a document and it"s references.
 *
 * Once populated, ClassMetadata instances are usually cached in a serialized form.
 *
 * <b>IMPORTANT NOTE:</b>
 *
 * The fields of this class are only public for 2 reasons:
 * 1) To allow fast READ access.
 * 2) To drastically reduce the size of a serialized instance (private/protected members
 *    get the whole class name, namespace inclusive, prepended to every property in
 *    the serialized representation).
 *
 * @since       1.0
 * @author      Jonathan H. Wage <jonwage@gmail.com>
 * @author      Roman Borschel <roman@code-factory.org>
 */
class ClassMetadata extends ClassMetadataInfo
{
    /**
     * The ReflectionProperty instances of the mapped class.
     *
     * @var \ReflectionProperty[]
     */
    public reflFields = [];

    /**
     * The prototype from which new instances of the mapped class are created.
     *
     * @var object
     */
    private prototype;

    /**
     * Initializes a new ClassMetadata instance that will hold the object-document mapping
     * metadata of the class with the given name.
     *
     * @param string documentName The name of the document class the new instance is used for.
     */
    public function __construct(documentName)
    {
        parent::__construct(documentName);
        let this->reflClass = new \ReflectionClass(documentName);
        let this->namespace1 = this->reflClass->getNamespaceName();
        this->setCollection(this->reflClass->getShortName());
    }

    /**
     * Map a field.
     *
     * @param array mapping The mapping information.
     * @return void
     */
    public function mapField(array mapping)
    {
        var reflProp;

        let mapping = parent::mapField(mapping);

        if this->reflClass->hasProperty(mapping["fieldName"]) {
            let reflProp = this->reflClass->getProperty(mapping["fieldName"]);
            reflProp->setAccessible(true);
            let this->reflFields[mapping["fieldName"]] = reflProp;
        }
    }

    /**
     * Determines which fields get serialized.
     *
     * It is only serialized what is necessary for best unserialization performance.
     * That means any metadata properties that are not set or empty or simply have
     * their default value are NOT serialized.
     *
     * Parts that are also NOT serialized because they can not be properly unserialized:
     *      - reflClass (ReflectionClass)
     *      - reflFields (ReflectionProperty array)
     *
     * @return array The names of all the fields that should be serialized.
     */
    public function __sleep()
    {
        var serialized;

        // This metadata is always serialized/cached.
        let serialized = [
            "fieldMappings",
            "associationMappings",
            "identifier",
            "name",
            "namespace", // TODO: REMOVE
            "db",
            "collection",
            "rootDocumentName",
            "generatorType",
            "generatorOptions",
            "idGenerator",
            "indexes"
        ];

        // The rest of the metadata is only serialized if necessary.
        if this->changeTrackingPolicy != self::CHANGETRACKING_DEFERRED_IMPLICIT {
            let serialized[] = "changeTrackingPolicy";
        }

        if this->customRepositoryClassName {
            let serialized[] = "customRepositoryClassName";
        }

        if this->inheritanceType != self::INHERITANCE_TYPE_NONE {
            let serialized[] = "inheritanceType";
            let serialized[] = "discriminatorField";
            let serialized[] = "discriminatorValue";
            let serialized[] = "discriminatorMap";
            let serialized[] = "parentClasses";
            let serialized[] = "subClasses";
        }

        if this->isMappedSuperclass {
            let serialized[] = "isMappedSuperclass";
        }

        if this->isEmbeddedDocument {
            let serialized[] = "isEmbeddedDocument";
        }

        if this->isVersioned {
            let serialized[] = "isVersioned";
            let serialized[] = "versionField";
        }

        if this->lifecycleCallbacks {
            let serialized[] = "lifecycleCallbacks";
        }

        if this->file {
            let serialized[] = "file";
        }

        if this->slaveOkay {
            let serialized[] = "slaveOkay";
        }

        if this->distance {
            let serialized[] = "distance";
        }

        return serialized;
    }

    /**
     * Restores some state that can not be serialized/unserialized.
     *
     * @return void
     */
    public function __wakeup()
    {
        var field, mapping, reflField;

        // Restore ReflectionClass and properties
        let this->reflClass = new \ReflectionClass(this->name);

        for field, mapping in this->fieldMappings {
            if isset mapping["declared"] {
                let reflField = new \ReflectionProperty(mapping["declared"], field);
            } else {
                let reflField = this->reflClass->getProperty(field);
            }
            reflField->setAccessible(true);
            let this->reflFields[field] = reflField;
        }
    }

    /**
     * Creates a new instance of the mapped class, without invoking the constructor.
     *
     * @return object
     */
    public function newInstance()
    {
        if this->prototype === null {
            let this->prototype = version_compare(PHP_VERSION, "5.4.0", ">=")
                ? this->reflClass->newInstanceWithoutConstructor()
                : unserialize(sprintf("O:%d:'%s':0:{}", strlen(this->name), this->name));
        }

        return clone this->prototype;
    }
}