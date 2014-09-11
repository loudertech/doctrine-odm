
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

namespace Doctrine\ODM\MongoDB;

use Doctrine\Common\EventManager;
use Doctrine\Common\Persistence\ObjectManager;
use Doctrine\MongoDB\Connection;
use Doctrine\ODM\MongoDB\Hydrator\HydratorFactory;
use Doctrine\ODM\MongoDB\Mapping\ClassMetadata;
use Doctrine\ODM\MongoDB\Mapping\ClassMetadataFactory;
use Doctrine\ODM\MongoDB\Proxy\ProxyFactory;
use Doctrine\ODM\MongoDB\Query\FilterCollection;

/**
 * The DocumentManager class is the central access point for managing the
 * persistence of documents.
 *
 *     <?php
 *
 *     $config = new Configuration();
 *     $dm = DocumentManager::create(new Connection(), $config);
 *
 * @since       1.0
 * @author      Jonathan H. Wage <jonwage@gmail.com>
 * @author      Roman Borschel <roman@code-factory.org>
 */
class DocumentManager implements ObjectManager
{
    /**
     * The Doctrine MongoDB connection instance.
     *
     * @var \Doctrine\MongoDB\Connection
     */
    private connection;

    /**
     * The used Configuration.
     *
     * @var \Doctrine\ODM\MongoDB\Configuration
     */
    private config;

    /**
     * The metadata factory, used to retrieve the ODM metadata of document classes.
     *
     * @var \Doctrine\ODM\MongoDB\Mapping\ClassMetadataFactory
     */
    private metadataFactory;

    /**
     * The DocumentRepository instances.
     *
     * @var array
     */
    private repositories;

    /**
     * The UnitOfWork used to coordinate object-level transactions.
     *
     * @var UnitOfWork
     */
    private unitOfWork;

    /**
     * The event manager that is the central point of the event system.
     *
     * @var \Doctrine\Common\EventManager
     */
    private eventManager;

    /**
     * The Hydrator factory instance.
     *
     * @var HydratorFactory
     */
    private hydratorFactory;

    /**
     * The Proxy factory instance.
     *
     * @var ProxyFactory
     */
    private proxyFactory;

    /**
     * SchemaManager instance
     *
     * @var SchemaManager
     */
    private schemaManager;

    /**
     * Array of cached document database instances that are lazily loaded.
     *
     * @var array
     */
    private documentDatabases;

    /**
     * Array of cached document collection instances that are lazily loaded.
     *
     * @var array
     */
    private documentCollections;

    /**
     * Whether the DocumentManager is closed or not.
     *
     * @var bool
     */
    private closed = false;

    /**
     * Collection of query filters.
     *
     * @var \Doctrine\ODM\MongoDB\Query\FilterCollection
     */
    private filterCollection;

    /**
     * Creates a new Document that operates on the given Mongo connection
     * and uses the given Configuration.
     *
     * @param \Doctrine\MongoDB\Connection|null $conn
     * @param Configuration|null $config
     * @param \Doctrine\Common\EventManager|null $eventManager
     */
    protected function __construct(conn, config, eventManager)
    {
        var metadataFactoryClassName, cacheDriver, hydratorDir, hydratorNs,
            unitOfWork, metadataFactory, hydratorFactory;

        let this->config       = config;
        let this->eventManager = eventManager;
        let this->connection   = conn;

        let metadataFactoryClassName = config->getClassMetadataFactoryName();
        let metadataFactory = new {metadataFactoryClassName}(), this->metadataFactory = metadataFactory;
        metadataFactory->setDocumentManager(this);
        metadataFactory->setConfiguration(config);

        let cacheDriver = config->getMetadataCacheImpl();
        if cacheDriver {
            metadataFactory->setCacheDriver($cacheDriver);
        }

        let hydratorDir = config->getHydratorDir();
        let hydratorNs = config->getHydratorNamespace();

        let hydratorFactory = new Hydrator\HydratorFactory(
            this,
            eventManager,
            hydratorDir,
            hydratorNs,
            config->getAutoGenerateHydratorClasses()
        );

        let this->hydratorFactory = hydratorFactory;

        let unitOfWork = new UnitOfWork(this, eventManager, hydratorFactory), this->unitOfWork = unitOfWork;

        this->hydratorFactory->setUnitOfWork(unitOfWork);

        let this->schemaManager = new SchemaManager(this, metadataFactory),
            this->proxyFactory = new Proxy\ProxyFactory(this,
                config->getProxyDir(),
                config->getProxyNamespace(),
                config->getAutoGenerateProxyClasses()
            );
    }

    /**
     * Gets the proxy factory used by the DocumentManager to create document proxies.
     *
     * @return ProxyFactory
     */
    public final function getProxyFactory()
    {
        return this->proxyFactory;
    }

    /**
     * Creates a new Document that operates on the given Mongo connection
     * and uses the given Configuration.
     *
     * @static
     * @param \Doctrine\MongoDB\Connection|null $conn
     * @param Configuration|null $config
     * @param \Doctrine\Common\EventManager|null $eventManager
     * @return DocumentManager
     */
    public final static function create(conn = null, config = null, eventManager = null)
    {
        return new self(conn, config, eventManager);
    }

    /**
     * Gets the EventManager used by the DocumentManager.
     *
     * @return \Doctrine\Common\EventManager
     */
    public final function getEventManager()
    {
        return this->eventManager;
    }

    /**
     * Gets the PHP Mongo instance that this DocumentManager wraps.
     *
     * @return \Doctrine\MongoDB\Connection
     */
    public final function getConnection()
    {
        return this->connection;
    }

    /**
     * Gets the metadata factory used to gather the metadata of classes.
     *
     * @return \Doctrine\ODM\MongoDB\Mapping\ClassMetadataFactory
     */
    public final function getMetadataFactory()
    {
        return this->metadataFactory;
    }

    /**
     * Helper method to initialize a lazy loading proxy or persistent collection.
     *
     * This method is a no-op for other objects.
     *
     * @param object $obj
     */
    public final function initializeObject(obj)
    {
        this->unitOfWork->initializeObject(obj);
    }

    /**
     * Gets the UnitOfWork used by the DocumentManager to coordinate operations.
     *
     * @return UnitOfWork
     */
    public final function getUnitOfWork()
    {
        return this->unitOfWork;
    }

    /**
     * Gets the Hydrator factory used by the DocumentManager to generate and get hydrators
     * for each type of document.
     *
     * @return \Doctrine\ODM\MongoDB\Hydrator\HydratorInterface
     */
    public final function getHydratorFactory()
    {
        return this->hydratorFactory;
    }

    /**
     * Returns SchemaManager, used to create/drop indexes/collections/databases.
     *
     * @return \Doctrine\ODM\MongoDB\SchemaManager
     */
    public final function getSchemaManager()
    {
        return this->schemaManager;
    }

    /**
     * Returns the metadata for a class.
     *
     * @param string $className The class name.
     * @return \Doctrine\ODM\MongoDB\Mapping\ClassMetadata
     * @internal Performance-sensitive method.
     */
    public final function getClassMetadata(className)
    {
        var newClassName;
        if starts_with(className, "\\") {
            let newClassName = ltrim(className, "\\");
        } else {
            let newClassName = className;
        }
        return this->metadataFactory->getMetadataFor(newClassName);
    }

    /**
     * Returns the MongoDB instance for a class.
     *
     * @param string $className The class name.
     * @return \Doctrine\MongoDB\Database
     */
    public final function getDocumentDatabase(className)
    {
        var newClassName, documentDatabase, db, metadata;

        if starts_with(className, "\\") {
            let newClassName = ltrim(className, "\\");
        } else {
            let newClassName = className;
        }

        if fetch documentDatabase, this->documentDatabases[newClassName] {
            return documentDatabase;
        }

        let metadata = this->metadataFactory->getMetadataFor(newClassName);

        let db = metadata->getDatabase(),
            db = db ? db : this->config->getDefaultDB(),
            db = db ? db : "doctrine",
            documentDatabase = this->connection->selectDatabase(db),
            this->documentDatabases[newClassName] = documentDatabase;

        return documentDatabase;
    }

    /**
     * Gets the array of instantiated document database instances.
     *
     * @return array
     */
    public final function getDocumentDatabases()
    {
        return this->documentDatabases;
    }

    /**
     * Returns the MongoCollection instance for a class.
     *
     * @param string $className The class name.
     * @throws MongoDBException When the $className param is not mapped to a collection
     * @return \Doctrine\MongoDB\Collection
     */
    public final function getDocumentCollection(className)
    {
        var newClassName, collectionName, collection, db, metadata;

        if starts_with(className, "\\") {
            let newClassName = ltrim(className, "\\");
        } else {
            let newClassName = className;
        }

        let metadata = this->metadataFactory->getMetadataFor(newClassName),
            collectionName = metadata->getCollection();

        if !collectionName {
            //throw MongoDBException::documentNotMappedToCollection($className);
            throw new \Exception("?");
        }

        if !fetch collection, this->documentCollections[newClassName] {
            let db = this->getDocumentDatabase(newClassName);
            let collection = metadata->isFile() ? db->getGridFS(collectionName) : db->selectCollection(collectionName);
            let this->documentCollections[newClassName] = collection;
        }

        if metadata->slaveOkay !== null {
            collection->setSlaveOkay(metadata->slaveOkay);
        }

        return this->documentCollections[className];
    }

    /**
     * Gets the array of instantiated document collection instances.
     *
     * @return array
     */
    public final function getDocumentCollections()
    {
        return this->documentCollections;
    }

    /**
     * Create a new Query instance for a class.
     *
     * @param string $documentName The document class name.
     * @return Query\Builder
     */
    public final function createQueryBuilder(documentName = null)
    {
        return new Query\Builder(this, documentName);
    }

    /**
     * Tells the DocumentManager to make an instance managed and persistent.
     *
     * The document will be entered into the database at or before transaction
     * commit or as a result of the flush operation.
     *
     * NOTE: The persist operation always considers documents that are not yet known to
     * this DocumentManager as NEW. Do not pass detached documents to the persist operation.
     *
     * @param object $document The instance to make managed and persistent.
     * @throws \InvalidArgumentException When the given $document param is not an object
     */
    public final function persist(document)
    {
        if !is_object(document) {
            throw new \InvalidArgumentException(gettype(document));
        }
        this->errorIfClosed();
        this->unitOfWork->persist($document);
    }

    /**
     * Removes a document instance.
     *
     * A removed document will be removed from the database at or before transaction commit
     * or as a result of the flush operation.
     *
     * @param object $document The document instance to remove.
     * @throws \InvalidArgumentException when the $document param is not an object
     */
    public final function remove(document)
    {
        if !is_object(document) {
            throw new \InvalidArgumentException(gettype(document));
        }
        this->errorIfClosed();
        this->unitOfWork->remove($document);
    }

    /**
     * Refreshes the persistent state of a document from the database,
     * overriding any local changes that have not yet been persisted.
     *
     * @param object $document The document to refresh.
     * @throws \InvalidArgumentException When the given $document param is not an object
     */
    public final function refresh(document)
    {
        if !is_object(document) {
            throw new \InvalidArgumentException(gettype(document));
        }
        this->errorIfClosed();
        this->unitOfWork->refresh(document);
    }

    /**
     * Detaches a document from the DocumentManager, causing a managed document to
     * become detached.  Unflushed changes made to the document if any
     * (including removal of the document), will not be synchronized to the database.
     * Documents which previously referenced the detached document will continue to
     * reference it.
     *
     * @param object $document The document to detach.
     * @throws \InvalidArgumentException when the $document param is not an object
     */
    public final function detach(document)
    {
        if !is_object($document) {
            throw new \InvalidArgumentException(gettype(document));
        }
        this->unitOfWork->detach(document);
    }

    /**
     * Merges the state of a detached document into the persistence context
     * of this DocumentManager and returns the managed copy of the document.
     * The document passed to merge will not become associated/managed with this DocumentManager.
     *
     * @param object $document The detached document to merge into the persistence context.
     * @throws LockException
     * @throws \InvalidArgumentException if the $document param is not an object
     * @return object The managed copy of the document.
     */
    public final function merge(document)
    {
        if (!is_object(document)) {
            throw new \InvalidArgumentException(gettype($document));
        }
        this->errorIfClosed();
        return this->unitOfWork->merge($document);
    }

    /**
     * Acquire a lock on the given document.
     *
     * @param object $document
     * @param int $lockMode
     * @param int $lockVersion
     * @throws \InvalidArgumentException
     */
    public final function lock($document, $lockMode, $lockVersion = null)
    {
        if !is_object($document) {
            throw new \InvalidArgumentException(gettype($document));
        }
        this->unitOfWork->lock($document, $lockMode, $lockVersion);
    }

    /**
     * Releases a lock on the given document.
     *
     * @param object $document
     * @throws \InvalidArgumentException if the $document param is not an object
     */
    public final function unlock(document)
    {
        if !is_object(document) {
            throw new \InvalidArgumentException(gettype(document));
        }
        this->unitOfWork->unlock(document);
    }

    /**
     * Gets the repository for a document class.
     *
     * @param string $documentName  The name of the Document.
     * @return DocumentRepository  The repository.
     */
    public final function getRepository($documentName)
    {
        var newDocumentName, repository, metadata, customRepositoryClassName;

        let newDocumentName = ltrim(documentName, "\\");

        if fetch repository, this->repositories[newDocumentName] {
            return repository;
        }

        let metadata = this->getClassMetadata(newDocumentName),
            customRepositoryClassName = metadata->customRepositoryClassName;

        if customRepositoryClassName !== null {
            let repository = new {customRepositoryClassName}(this, this->unitOfWork, metadata);
        } else {
            let repository = new DocumentRepository(this, this->unitOfWork, metadata);
        }

        let this->repositories[documentName] = repository;

        return repository;
    }

    /**
     * Flushes all changes to objects that have been queued up to now to the database.
     * This effectively synchronizes the in-memory state of managed objects with the
     * database.
     *
     * @param object $document
     * @param array $options Array of options to be used with batchInsert(), update() and remove()
     * @throws \InvalidArgumentException
     */
    public final function flush(document = null, array options = [])
    {
        if (null !== document && !is_object($document) && !is_array($document)) {
            throw new \InvalidArgumentException(gettype($document));
        }
        this->errorIfClosed();
        this->unitOfWork->commit($document, $options);
    }

    /**
     * Gets a reference to the document identified by the given type and identifier
     * without actually loading it.
     *
     * If partial objects are allowed, this method will return a partial object that only
     * has its identifier populated. Otherwise a proxy is returned that automatically
     * loads itself on first access.
     *
     * @param string $documentName
     * @param string|object $identifier
     * @return mixed|object The document reference.
     */
    public final function getReference(documentName, identifier)
    {
        var classInstance, document, name;

        let classInstance = this->metadataFactory->getMetadataFor(ltrim(documentName, "\\"));

        // Check identity map first, if its already in there just return it.
        let document = this->unitOfWork->tryGetById(identifier, classInstance);
        if document {
            return document;
        }

        let name = classInstance->identifier,
            document = this->proxyFactory->getProxy(classInstance->name, [
               name : identifier
            ]);
        this->unitOfWork->registerManaged(document, identifier, []);

        return document;
    }

    /**
     * Gets a partial reference to the document identified by the given type and identifier
     * without actually loading it, if the document is not yet loaded.
     *
     * The returned reference may be a partial object if the document is not yet loaded/managed.
     * If it is a partial object it will not initialize the rest of the document state on access.
     * Thus you can only ever safely access the identifier of a document obtained through
     * this method.
     *
     * The use-cases for partial references involve maintaining bidirectional associations
     * without loading one side of the association or to update a document without loading it.
     * Note, however, that in the latter case the original (persistent) document data will
     * never be visible to the application (especially not event listeners) as it will
     * never be loaded in the first place.
     *
     * @param string $documentName The name of the document type.
     * @param mixed $identifier The document identifier.
     * @return object The (partial) document reference.
     */
    public final function getPartialReference($documentName, $identifier)
    {
        var classInstance, document;

        let classInstance = this->metadataFactory->getMetadataFor(ltrim(documentName, "\\"));

        // Check identity map first, if its already in there just return it.
        let document = this->unitOfWork->tryGetById(identifier, classInstance);
        if document {
            return document;
        }

        let document = classInstance->newInstance();
        classInstance->setIdentifierValue(document, identifier);
        this->unitOfWork->registerManaged(document, identifier, []);

        return document;
    }

    /**
     * Finds a Document by its identifier.
     *
     * This is just a convenient shortcut for getRepository($documentName)->find($id).
     *
     * @param string $documentName
     * @param mixed $identifier
     * @param int $lockMode
     * @param int $lockVersion
     * @return object $document
     */
    public final function find($documentName, identifier, lockMode = LockMode::NONE, lockVersion = null)
    {
        return this->getRepository(documentName)->find(identifier, lockMode, lockVersion);
    }

    /**
     * Clears the DocumentManager.
     *
     * All documents that are currently managed by this DocumentManager become
     * detached.
     *
     * @param string|null $documentName if given, only documents of this type will get detached
     */
    public final function clear($documentName = null)
    {
        this->unitOfWork->clear($documentName);
    }

    /**
     * Closes the DocumentManager. All documents that are currently managed
     * by this DocumentManager become detached. The DocumentManager may no longer
     * be used after it is closed.
     */
    public final function close()
    {
        this->clear();
        let this->closed = true;
    }

    /**
     * Determines whether a document instance is managed in this DocumentManager.
     *
     * @param object $document
     * @throws \InvalidArgumentException When the $document param is not an object
     * @return boolean TRUE if this DocumentManager currently manages the given document, FALSE otherwise.
     */
    public final function contains($document)
    {
        var unitOfWork;

        if !is_object($document) {
            throw new \InvalidArgumentException(gettype($document));
        }

        let unitOfWork = this->unitOfWork;

        return unitOfWork->isScheduledForInsert(document) ||
               unitOfWork->isInIdentityMap(document) &&
               unitOfWork->isScheduledForDelete($document);
    }

    /**
     * Gets the Configuration used by the DocumentManager.
     *
     * @return Configuration
     */
    public final function getConfiguration()
    {
        return this->config;
    }

    /**
     * Returns a DBRef array for the supplied document.
     *
     * @param mixed $document A document object
     * @param array $referenceMapping Mapping for the field that references the document
     *
     * @throws \InvalidArgumentException
     * @return array A DBRef array
     */
    public final function xcreateDBRef($document, array $referenceMapping = null)
    {
        /*if (!is_object($document)) {
            throw new \InvalidArgumentException('Cannot create a DBRef, the document is not an object');
        }

        $class = this->getClassMetadata(get_class($document));
        $id = this->unitOfWork->getDocumentIdentifier($document);

        if (!$id) {
            throw new \RuntimeException(
                sprintf('Cannot create a DBRef without an identifier. UnitOfWork::getDocumentIdentifier() did not return an identifier for class %s', $class->name)
            );
        }

        if ( ! empty($referenceMapping['simple'])) {
            return $class->getDatabaseIdentifierValue($id);
        }

        $dbRef = array(
            '$ref' => $class->getCollection(),
            '$id'  => $class->getDatabaseIdentifierValue($id),
            '$db'  => this->getDocumentDatabase($class->name)->getName(),
        );

        // If the class has a discriminator (field and value), use it. A child
        // class that is not defined in the discriminator map may only have a
        // discriminator field and no value, so default to the full class name.
        //
        if (isset($class->discriminatorField)) {
            $dbRef[$class->discriminatorField] = isset($class->discriminatorValue)
                ? $class->discriminatorValue
                : $class->name;
        }

        // Add a discriminator value if the referenced document is not mapped
        // explicitly to a targetDocument class.
        //
        if ($referenceMapping !== null && ! isset($referenceMapping['targetDocument'])) {
            $discriminatorField = $referenceMapping['discriminatorField'];
            $discriminatorValue = isset($referenceMapping['discriminatorMap'])
                ? array_search($class->name, $referenceMapping['discriminatorMap'])
                : $class->name;

            // If the discriminator value was not found in the map, use the full
            // class name. In the future, it may be preferable to throw an
            // exception here (perhaps based on some strictness option).
            //
            // @see PersistenceBuilder::prepareEmbeddedDocumentValue()
            //
            if ($discriminatorValue === false) {
                $discriminatorValue = $class->name;
            }

            $dbRef[$discriminatorField] = $discriminatorValue;
        }

        return $dbRef;*/
    }

    /**
     * Throws an exception if the DocumentManager is closed or currently not active.
     *
     * @throws MongoDBException If the DocumentManager is closed.
     */
    private function errorIfClosed()
    {
        if this->closed {
            //throw MongoDBException::documentManagerClosed();
            throw new \Exception("?");
        }
    }

    /**
     * Check if the Document manager is open or closed.
     *
     * @return bool
     */
    public final function isOpen()
    {
        return !this->closed;
    }

    /**
     * Gets the filter collection.
     *
     * @return \Doctrine\ODM\MongoDB\Query\FilterCollection The active filter collection.
     */
    public final function getFilterCollection()
    {
        var filter;
        let filter = this->filterCollection;
        if filter === null {
            let filter = new Query\FilterCollection(this), this->filterCollection = filter;
        }
        return filter;
    }
}
