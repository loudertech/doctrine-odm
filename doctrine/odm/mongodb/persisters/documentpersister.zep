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

namespace Doctrine\ODM\MongoDB\Persisters;

use Doctrine\Common\EventManager;
use Doctrine\MongoDB\Cursor as BaseCursor;
use Doctrine\ODM\MongoDB\Cursor;
use Doctrine\ODM\MongoDB\DocumentManager;
use Doctrine\ODM\MongoDB\Hydrator\HydratorFactory;
use Doctrine\ODM\MongoDB\LockException;
use Doctrine\ODM\MongoDB\LockMode;
use Doctrine\ODM\MongoDB\Mapping\ClassMetadata;
use Doctrine\ODM\MongoDB\Mapping\ClassMetadataInfo;
use Doctrine\ODM\MongoDB\PersistentCollection;
use Doctrine\ODM\MongoDB\Proxy\Proxy;
use Doctrine\ODM\MongoDB\Query\CriteriaMerger;
use Doctrine\ODM\MongoDB\Query\Query;
use Doctrine\ODM\MongoDB\Types\Type;
use Doctrine\ODM\MongoDB\UnitOfWork;

/**
 * The DocumentPersister is responsible for persisting documents.
 *
 * @since       1.0
 * @author      Jonathan H. Wage <jonwage@gmail.com>
 * @author      Bulat Shakirzyanov <bulat@theopenskyproject.com>
 */
class DocumentPersister
{
    /**
     * The PersistenceBuilder instance.
     *
     * @var PersistenceBuilder
     */
    private pb;

    /**
     * The DocumentManager instance.
     *
     * @var DocumentManager
     */
    private dm;

    /**
     * The EventManager instance
     *
     * @var EventManager
     */
    private evm;

    /**
     * The UnitOfWork instance.
     *
     * @var UnitOfWork
     */
    private uow;

    /**
     * The Hydrator instance
     *
     * @var HydratorInterface
     */
    private hydrator;
    private hydratorFactory;

    /**
     * The ClassMetadata instance for the document type being persisted.
     *
     * @var ClassMetadata
     */
    private class1;

    /**
     * The MongoCollection instance for this document.
     *
     * @var \MongoCollection
     */
    private collection;

    /**
     * Array of queued inserts for the persister to insert.
     *
     * @var array
     */
    private queuedInserts = [];

    /**
     * Array of queued inserts for the persister to insert.
     *
     * @var array
     */
    private queuedUpserts = [];

    /**
     * The CriteriaMerger instance.
     *
     * @var CriteriaMerger
     */
    private cm;

    /**
     * Initializes a new DocumentPersister instance.
     *
     * @param PersistenceBuilder pb
     * @param DocumentManager dm
     * @param EventManager evm
     * @param UnitOfWork uow
     * @param HydratorFactory hydratorFactory
     * @param ClassMetadata class
     */
    public function __construct( pb,  dm,  evm,  uow,  hydratorFactory,  class1,  cm = null)
    {
        let this->pb = pb;
        let this->dm = dm;
        let this->evm = evm;
        let this->cm = cm ? "" : new CriteriaMerger();
        let this->uow = uow;
        let this->hydratorFactory = hydratorFactory;
        let this->class1 = class1;
        let this->collection = dm->getDocumentCollection(class1->name);
    }

    /**
     * @return array
     */
    public function getInserts()
    {
        return this->queuedInserts;
    }

    /**
     * @param object document
     * @return bool
     */
    public function isQueuedForInsert(document)
    {
        return isset this->queuedInserts[spl_object_hash(document)];
    }

    /**
     * Adds a document to the queued insertions.
     * The document remains queued until {@link executeInserts} is invoked.
     *
     * @param object document The document to queue for insertion.
     */
    public function addInsert(document)
    {
        let this->queuedInserts[spl_object_hash(document)] = document;
    }

    /**
     * @return array
     */
    public function getUpserts()
    {
        return this->queuedUpserts;
    }

    /**
     * @param object document
     * @return boolean
     */
    public function isQueuedForUpsert(document)
    {
        return isset this->queuedUpserts[spl_object_hash(document)];
    }

    /**
     * Adds a document to the queued upserts.
     * The document remains queued until {@link executeUpserts} is invoked.
     *
     * @param object document The document to queue for insertion.
     */
    public function addUpsert(document)
    {
        let this->queuedUpserts[spl_object_hash(document)] = document;
    }

    /**
     * Gets the ClassMetadata instance of the document class this persister is used for.
     *
     * @return ClassMetadata
     */
    public function getClassMetadata()
    {
        return this->class1;
    }

    /**
     * Executes all queued document insertions.
     *
     * Queued documents without an ID will inserted in a batch and queued
     * documents with an ID will be upserted individually.
     *
     * If no inserts are queued, invoking this method is a NOOP.
     *
     * @param array options Options for batchInsert() and update() driver methods
     */
    public function executeInserts(array options = [])
    {
        var inserts, oid, document, versionMapping, nextVersion, data, nextVersionDateTime;

        if  ! this->queuedInserts {
            return;
        }

        let inserts = [];
        for oid, document in this->queuedInserts {
            let data = this->pb->prepareInsertData(document);

            // Set the initial version for each insert
            if this->class1->isVersioned {
                let versionMapping = this->class1->fieldMappings[this->class1->versionField];
                if versionMapping["type"] === "int" {
                    let nextVersion = this->class1->reflFields[this->class1->versionField]->getValue(document);
                    this->class1->reflFields[this->class1->versionField]->setValue(document, nextVersion);
                } else {
                    if versionMapping["type"] === "date" {
                        let nextVersionDateTime = new \DateTime();
                        let nextVersion = new \MongoDate(nextVersionDateTime->getTimestamp());
                        this->class1->reflFields[this->class1->versionField]->setValue(document, nextVersionDateTime);
                    }
                }
                let data[versionMapping["name"]] = nextVersion;
            }

            let inserts[oid] = data;
        }

        if inserts {
            //try {
                this->collection->batchInsert(inserts, options);
            //} catch (\MongoException e) {
            //    this->queuedInserts = [];
            //    throw e;
            //}
        }

        let this->queuedInserts = [];
    }

    /**
     * Executes all queued document upserts.
     *
     * Queued documents with an ID are upserted individually.
     *
     * If no upserts are queued, invoking this method is a NOOP.
     *
     * @param array options Options for batchInsert() and update() driver methods
     */
    public function executeUpserts(array options = [])
    {
        var oid, document, data;

        if  !this->queuedUpserts {
            return;
        }

        for oid, document in this->queuedUpserts {
            let data = this->pb->prepareUpsertData(document);

            //try {
                this->executeUpsert(data, options);
                unset(this->queuedUpserts[oid]);
            //} catch (\MongoException e) {
            //    unset(this->queuedUpserts[oid]);
            //    throw e;
            //}
        }
    }

    /**
     * Executes a single upsert in {@link executeInserts}
     *
     * @param array data
     * @param array options
     */
    private function executeUpsert(array data, array options)
    {
        var criteria, retry;

        let options["upsert"] = true;
        let criteria = ["_id" : data["set"]["_id"]];
        unset(data["set"]["_id"]);

        // Do not send an empty set modifier
        if isset data["set"] {
            unset(data["set"]);
        }

        /* If there are no modifiers remaining, we"re upserting a document with 
         * an identifier as its only field. Since a document with the identifier
         * may already exist, the desired behavior is "insert if not exists" and
         * NOOP otherwise. MongoDB 2.6+ does not allow empty modifiers, so set
         * the identifier to the same value in our criteria.
         *
         * This will fail for versions before MongoDB 2.6, which require an
         * empty set modifier. The best we can do (without attempting to check
         * server versions in advance) is attempt the 2.6+ behavior and retry
         * after the relevant exception.
         *
         * See: https://jira.mongodb.org/browse/SERVER-12266
         */
        if count(data) > 0 {
            let retry = true;
            let data = ["set" : ["_id" : criteria["_id"]]];
        }

        //try {
            this->collection->update(criteria, data, options);
            return;
        //} catch (\MongoCursorException e) {
        //    if empty retry || strpos(e->getMessage(), "Mod on _id not allowed") === false {
        //        throw e;
        //    }
        //}

        this->collection->update(criteria, ["set" : new \stdClass], options);
    }

    /**
     * Updates the already persisted document if it has any new changesets.
     *
     * @param object document
     * @param array options Array of options to be used with update()
     * @throws \Doctrine\ODM\MongoDB\LockException
     */
    public function update(document, array options = [])
    {
        var id, update, query, versionMapping, currentVersion, nextVersion, isLocked, lockMapping,
            a, result;

        let id = this->uow->getDocumentIdentifier(document);
        let update = this->pb->prepareUpdateData(document);

        if  !empty update {

            let id = this->class1->getDatabaseIdentifierValue(id);
            let query = ["_id" : id];

            // Include versioning logic to set the new version value in the database
            // and to ensure the version has not changed since this document object instance
            // was fetched from the database
            if this->class1->isVersioned {
                let versionMapping = this->class1->fieldMappings[this->class1->versionField];
                let currentVersion = this->class1->reflFields[this->class1->versionField]->getValue(document);
                if versionMapping["type"] === "int" {
                    let nextVersion = currentVersion + 1;
                    let update["inc"][versionMapping["name"]] = 1;
                    let query[versionMapping["name"]] = currentVersion;
                    this->class1->reflFields[this->class1->versionField]->setValue(document, nextVersion);
                } else {
                    if versionMapping["type"] === "date" {
                        let nextVersion = new \DateTime();
                        let update["set"][versionMapping["name"]] = new \MongoDate(nextVersion->getTimestamp());
                        let query[versionMapping["name"]] = new \MongoDate(currentVersion->getTimestamp());
                        this->class1->reflFields[this->class1->versionField]->setValue(document, nextVersion);
                    }
                }
            }

            // Include locking logic so that if the document object in memory is currently
            // locked then it will remove it, otherwise it ensures the document is not locked.
            if this->class1->isLockable {
                let isLocked = this->class1->reflFields[this->class1->lockField]->getValue(document);
                let lockMapping = this->class1->fieldMappings[this->class1->lockField];
                if isLocked {
                    let a = lockMapping["name"];
                    let update["unset"] = [a: true];
                } else {
                    let query[lockMapping["name"]] = ["exists": false];
                }
            }

            unset(update["set"]["_id"]);
            let result = this->collection->update(query, update, options);

            if (this->class1->isVersioned || this->class1->isLockable) && ! result["n"] {
                throw LockException::lockFailed(document);
            }
        }
    }

    /**
     * Removes document from mongo
     *
     * @param mixed document
     * @param array options Array of options to be used with remove()
     * @throws \Doctrine\ODM\MongoDB\LockException
     */
    public function delete(document, array options = [])
    {
        var id, query, result;

        let id = this->uow->getDocumentIdentifier(document);
        let query = ["_id" : this->class1->getDatabaseIdentifierValue(id)];

        if this->class1->isLockable {
            let query[this->class1->lockField] = ["exists" : false];
        }

        let result = this->collection->remove(query, options);

        if (this->class1->isVersioned || this->class1->isLockable) && ! result["n"] {
            throw LockException::lockFailed(document);
        }
    }

    /**
     * Refreshes a managed document.
     *
     * @param array id The identifier of the document.
     * @param object document The document to refresh.
     */
    public function refresh(id, document)
    {
        var class1, data;

        let class1 = this->dm->getClassMetadata(get_class(document));
        let data = this->collection->findOne(["_id" : id]);
        let data = this->hydratorFactory->hydrate(document, data);
        this->uow->setOriginalDocumentData(document, data);
    }

    /**
     * Finds a document by a set of criteria.
     *
     * If a scalar or MongoId is provided for criteria, it will be used to
     * match an _id value.
     *
     * @param mixed   criteria Query criteria
     * @param object  document Document to load the data into. If not specified, a new document is created.
     * @param array   hints    Hints for document creation
     * @param integer lockMode
     * @param array   sort     Sort array for Cursor::sort()
     * @throws \Doctrine\ODM\MongoDB\LockException
     * @return object|null The loaded and managed document instance or null if no document was found
     * @todo Check identity map? loadById method? Try to guess whether criteria is the id?
     */
    public function load(criteria, document = null, array hints = [], lockMode = 0, array sort = null)
    {
        var cursor, result, lockMapping;

        // TODO: remove this
        if criteria === null || is_scalar(criteria) || criteria instanceof \MongoId {
            let criteria = ["_id" : criteria];
        }

        let criteria = this->prepareQueryOrNewObj(criteria);
        let criteria = this->addDiscriminatorToPreparedQuery(criteria);
        let criteria = this->addFilterToPreparedQuery(criteria);

        let cursor = this->collection->find(criteria);

        if sort !== null {
            cursor->sort(this->prepareSortOrProjection(sort));
        }

        let result = cursor->getSingleResult();

        if this->class1->isLockable {
            let lockMapping = this->class1->fieldMappings[this->class1->lockField];
            if isset result[lockMapping["name"]] && result[lockMapping["name"]] === LockMode::PESSIMISTIC_WRITE {
                throw LockException::lockFailed(result);
            }
        }

        return this->createDocument(result, document, hints);
    }

    /**
     * Finds documents by a set of criteria.
     *
     * @param array        criteria Query criteria
     * @param array        sort     Sort array for Cursor::sort()
     * @param integer|null limit    Limit for Cursor::limit()
     * @param integer|null skip     Skip for Cursor::skip()
     * @return Cursor
     */
    public function loadAll(array criteria = [], array sort = null, limit = null, skip = null)
    {
        var baseCursor, cursor;

        let criteria = this->prepareQueryOrNewObj(criteria);
        let criteria = this->addDiscriminatorToPreparedQuery(criteria);
        let criteria = this->addFilterToPreparedQuery(criteria);

        let baseCursor = this->collection->find(criteria);
        let cursor = this->wrapCursor(baseCursor);

        /* The wrapped cursor may be used if the ODM cursor becomes wrapped with
         * an EagerCursor, so we should apply the same sort, limit, and skip
         * options to both cursors.
         */
        if sort !== null {
            baseCursor->sort(this->prepareSortOrProjection(sort));
            cursor->sort(sort);
        }

        if null !== limit {
            baseCursor->limit(limit);
            cursor->limit(limit);
        }

        if null !== skip {
            baseCursor->skip(skip);
            cursor->skip(skip);
        }

        return cursor;
    }

    /**
     * Wraps the supplied base cursor in the corresponding ODM class.
     *
     * @param BaseCursor cursor
     * @return Cursor
     */
    private function wrapCursor( baseCursor)
    {
        return new Cursor(baseCursor, this->dm->getUnitOfWork(), this->class1);
    }

    /**
     * Checks whether the given managed document exists in the database.
     *
     * @param object document
     * @return boolean TRUE if the document exists in the database, FALSE otherwise.
     */
    public function exists(document)
    {
        var id;
        let id = this->class1->getIdentifierObject(document);
        return (boolean) this->collection->findOne(["_id" : id], ["_id"]);
    }

    /**
     * Locks document by storing the lock mode on the mapped lock field.
     *
     * @param object document
     * @param int lockMode
     */
    public function lock(document, lockMode)
    {
        var id, criteria, lockMapping, a;

        let id = this->uow->getDocumentIdentifier(document);
        let criteria = ["_id" : this->class1->getDatabaseIdentifierValue(id)];
        let lockMapping = this->class1->fieldMappings[this->class1->lockField];
        let a = lockMapping["name"];
        this->collection->update(criteria, ["set" : [a : lockMode]]);
        this->class1->reflFields[this->class1->lockField]->setValue(document, lockMode);
    }

    /**
     * Releases any lock that exists on this document.
     *
     * @param object document
     */
    public function unlock(document)
    {
        var id, criteria, lockMapping, a;
        let id = this->uow->getDocumentIdentifier(document);
        let criteria = ["_id" : this->class1->getDatabaseIdentifierValue(id)];
        let lockMapping = this->class1->fieldMappings[this->class1->lockField];
        let a = lockMapping["name"];
        this->collection->update(criteria, ["unset" : [a : true]]);
        this->class1->reflFields[this->class1->lockField]->setValue(document, null);
    }

    /**
     * Creates or fills a single document object from an query result.
     *
     * @param object result The query result.
     * @param object document The document object to fill, if any.
     * @param array hints Hints for document creation.
     * @return object The filled and managed document object or NULL, if the query result is empty.
     */
    private function createDocument(result, document = null, array hints = [])
    {
        var id;

        if result === null {
            return null;
        }

        if document !== null {
            let hints[Query::HINT_REFRESH] = true;
            let id = this->class1->getPHPIdentifierValue(result["_id"]);
            this->uow->registerManaged(document, id, result);
        }

        return this->uow->getOrCreateDocument(this->class1->name, result, hints);
    }

    /**
     * Loads a PersistentCollection data. Used in the initialize() method.
     *
     * @param PersistentCollection collection
     */
    public function loadCollection( collection)
    {
        var mapping;

        let mapping = collection->getMapping();
        switch mapping["association"] {
            case ClassMetadataInfo::EMBED_MANY:
                this->loadEmbedManyCollection(collection);
                break;

            case ClassMetadataInfo::REFERENCE_MANY:
                if isset mapping["repositoryMethod"] && mapping["repositoryMethod"] {
                    this->loadReferenceManyWithRepositoryMethod(collection);
                } else {
                    if mapping["isOwningSide"] {
                        this->loadReferenceManyCollectionOwningSide(collection);
                    } else {
                        this->loadReferenceManyCollectionInverseSide(collection);
                    }
                }
                break;
        }
    }

    private function loadEmbedManyCollection( collection)
    {
        var embeddedDocuments, mapping, owner, key, embeddedDocument, className, embeddedMetadata,
            embeddedDocumentObject, data, id;

        let embeddedDocuments = collection->getMongoData();
        let mapping = collection->getMapping();
        let owner = collection->getOwner();
        if embeddedDocuments {
            for key, embeddedDocument in embeddedDocuments {
                let className = this->uow->getClassNameForAssociation(mapping, embeddedDocument);
                let embeddedMetadata = this->dm->getClassMetadata(className);
                let embeddedDocumentObject = embeddedMetadata->newInstance();

                let data = this->hydratorFactory->hydrate(embeddedDocumentObject, embeddedDocument);
                let id = embeddedMetadata->identifier && isset data[embeddedMetadata->identifier]
                    ? data[embeddedMetadata->identifier]
                    : null;

                this->uow->registerManaged(embeddedDocumentObject, id, data);
                this->uow->setParentAssociation(embeddedDocumentObject, mapping, owner, mapping["name"] . "." . key);
                if mapping["strategy"] === "set" {
                    collection->set(key, embeddedDocumentObject);
                } else {
                    collection->add(embeddedDocumentObject);
                }
            }
        }
    }

    private function loadReferenceManyCollectionOwningSide( collection)
    {
        var hints, mapping, groupedIds, sorted, key, reference, className, mongoId, id, class1,
            mongoCollection, criteria, ids, cursor, documents, documentData, document, data, 
            query;

        let hints = collection->getHints();
        let mapping = collection->getMapping();
        let groupedIds = [];

        let sorted = isset mapping["sort"] && mapping["sort"];

        for key, reference in collection->getMongoData() {
            if isset mapping["simple"] && mapping["simple"] {
                let className = mapping["targetDocument"];
                let mongoId = reference;
            } else {
                let className = this->uow->getClassNameForAssociation(mapping, reference);
                let mongoId = reference["id"];
            }
            let id = this->dm->getClassMetadata(className)->getPHPIdentifierValue(mongoId);

            // create a reference to the class and id
            let reference = this->dm->getReference(className, id);

            // no custom sort so add the references right now in the order they are embedded
            if  !sorted {
                if mapping["strategy"] === "set" {
                    collection->set(key, reference);
                } else {
                    collection->add(reference);
                }
            }

            // only query for the referenced object if it is not already initialized or the collection is sorted
            if ( (reference instanceof Proxy) && ! reference->__isInitialized__) || sorted {
                let groupedIds[className][] = mongoId;
            }
        }
        for className, ids in groupedIds {
            let class1 = this->dm->getClassMetadata(className);
            let mongoCollection = this->dm->getDocumentCollection(className);
            let criteria = this->cm->merge(
                ["_id" : ["in" : array_values(ids)]],
                this->dm->getFilterCollection()->getFilterCriteria(class1),
                isset mapping["criteria"] ? mapping["criteria"] : []
            );
            let criteria = this->uow->getDocumentPersister(className)->prepareQueryOrNewObj(criteria);
            let cursor = mongoCollection->find(criteria);
            if isset mapping["sort"] {
                cursor->sort(mapping["sort"]);
            }
            if isset mapping["limit"] {
                cursor->limit(mapping["limit"]);
            }
            if isset mapping["skip"] {
                cursor->skip(mapping["skip"]);
            }
            if  !empty hints[Query::HINT_SLAVE_OKAY] {
                cursor->slaveOkay(true);
            }
            if  !empty hints[Query::HINT_READ_PREFERENCE] {
                cursor->setReadPreference(hints[Query::HINT_READ_PREFERENCE], hints[Query::HINT_READ_PREFERENCE_TAGS]);
            }
            let documents = cursor->toArray(false);
            for documentData in documents {
                let document = this->uow->getById(documentData["_id"], class1);
                let data = this->hydratorFactory->hydrate(document, documentData);
                this->uow->setOriginalDocumentData(document, data);
                let document->__isInitialized__ = true;
                if sorted {
                    collection->add(document);
                }
            }
        }
    }

    private function loadReferenceManyCollectionInverseSide( collection)
    {
        var query, document, key, documents;

        let query = this->createReferenceManyInverseSideQuery(collection);
        let documents = query->execute()->toArray(false);
        for key, document in documents {
            collection->add(document);
        }
    }

    /**
     * @param PersistentCollection collection
     *
     * @return Query
     */
    public function createReferenceManyInverseSideQuery( collection)
    {
        var hints, mapping, owner, ownerClass, targetClass, mappedByMapping, mappedByFieldName,
            criteria, qb;

        let hints = collection->getHints();
        let mapping = collection->getMapping();
        let owner = collection->getOwner();
        let ownerClass = this->dm->getClassMetadata(get_class(owner));
        let targetClass = this->dm->getClassMetadata(mapping["targetDocument"]);
        let mappedByMapping = isset targetClass->fieldMappings[mapping["mappedBy"]] ? targetClass->fieldMappings[mapping["mappedBy"]] : [];
        let mappedByFieldName = isset mappedByMapping["simple"] && mappedByMapping["simple"] ? mapping["mappedBy"] : mapping["mappedBy"] . ".id";
        let criteria = this->cm->merge(
            [mappedByFieldName : ownerClass->getIdentifierObject(owner)],
            this->dm->getFilterCollection()->getFilterCriteria(targetClass),
            isset mapping["criteria"] ? mapping["criteria"] : []
        );
        let criteria = this->uow->getDocumentPersister(mapping["targetDocument"])->prepareQueryOrNewObj(criteria);
        let qb = this->dm->createQueryBuilder(mapping["targetDocument"])
            ->setQueryArray(criteria);

        if isset mapping["sort"] {
            qb->sort(mapping["sort"]);
        }
        if isset mapping["limit"] {
            qb->limit(mapping["limit"]);
        }
        if isset mapping["skip"] {
            qb->skip(mapping["skip"]);
        }
        if  !empty hints[Query::HINT_SLAVE_OKAY] {
            qb->slaveOkay(true);
        }
        if  !empty hints[Query::HINT_READ_PREFERENCE] {
            qb->setReadPreference(hints[Query::HINT_READ_PREFERENCE], hints[Query::HINT_READ_PREFERENCE_TAGS]);
        }

        return qb->getQuery();
    }

    private function loadReferenceManyWithRepositoryMethod( collection)
    {
        var cursor, documents, document;
        let cursor = this->createReferenceManyWithRepositoryMethodCursor(collection);
        let documents = cursor->toArray(false);
        for document in documents {
            collection->add(document);
        }
    }

    /**
     * @param PersistentCollection collection
     *
     * @return Cursor
     */
    public function createReferenceManyWithRepositoryMethodCursor( collection)
    {
        var hints, mapping, a, b, cursor;

        let hints = collection->getHints();
        let mapping = collection->getMapping();
        let a = this->dm->getRepository(mapping["targetDocument"]);
        let b = a->mapping["repositoryMethod"];
        let cursor = b(collection->getOwner());

        if isset mapping["sort"] {
            cursor->sort(mapping["sort"]);
        }
        if isset mapping["limit"] {
            cursor->limit(mapping["limit"]);
        }
        if isset mapping["skip"] {
            cursor->skip(mapping["skip"]);
        }
        if  !empty hints[Query::HINT_SLAVE_OKAY] {
            cursor->slaveOkay(true);
        }
        if  !empty hints[Query::HINT_READ_PREFERENCE] {
            cursor->setReadPreference(hints[Query::HINT_READ_PREFERENCE], hints[Query::HINT_READ_PREFERENCE_TAGS]);
        }

        return cursor;
    }

    /**
     * Prepare a sort or projection array by converting keys, which are PHP
     * property names, to MongoDB field names.
     *
     * @param array fields
     * @return array
     */
    public function prepareSortOrProjection(array fields)
    {
        var preparedFields, key, value;

        let preparedFields = [];

        for key, value in fields {
            let preparedFields[this->prepareFieldName(key)] = value;
        }

        return preparedFields;
    }

    /**
     * Prepare a mongodb field name and convert the PHP property names to MongoDB field names.
     *
     * @param string fieldName
     * @return string
     */
    public function prepareFieldName(fieldName)
    {
        var fieldNameArr;
        let fieldNameArr = this->prepareQueryElement(fieldName, null, null, false);

        return fieldNameArr[0];
    }

    /**
     * Adds discriminator criteria to an already-prepared query.
     *
     * This method should be used once for query criteria and not be used for
     * nested expressions. It should be called before
     * {@link DocumentPerister::addFilterToPreparedQuery()}.
     *
     * @param array preparedQuery
     * @return array
     */
    public function addDiscriminatorToPreparedQuery(array preparedQuery)
    {
        var discriminatorValues;

        /* If the class has a discriminator field, which is not already in the
         * criteria, inject it now. The field/values need no preparation.
         */
        if this->class1->hasDiscriminator() && !isset preparedQuery[this->class1->discriminatorField] {
            let discriminatorValues = this->getClassDiscriminatorValues(this->class1);
            let preparedQuery[this->class1->discriminatorField] = ["in" : discriminatorValues];
        }

        return preparedQuery;
    }

    /**
     * Adds filter criteria to an already-prepared query.
     *
     * This method should be used once for query criteria and not be used for
     * nested expressions. It should be called after
     * {@link DocumentPerister::addDiscriminatorToPreparedQuery()}.
     *
     * @param array preparedQuery
     * @return array
     */
    public function addFilterToPreparedQuery(array preparedQuery)
    {
        var a, filterCriteria;
        /* If filter criteria exists for this class, prepare it and merge
         * over the existing query.
         *
         * @todo Consider recursive merging in case the filter criteria and
         * prepared query both contain top-level and/or operators.
         */
        let a = this->dm->getFilterCollection();
        let filterCriteria = a->getFilterCriteria(this->class1);
        if filterCriteria {
            let preparedQuery = this->cm->merge(preparedQuery, this->prepareQueryOrNewObj(filterCriteria));
        }

        return preparedQuery;
    }

    /**
     * Prepares the query criteria or new document object.
     *
     * PHP field names and types will be converted to those used by MongoDB.
     *
     * @param array query
     * @return array
     */
    public function prepareQueryOrNewObj(array query)
    {
        var preparedQuery, key, value, list, k2, v2;

        let preparedQuery = [];

        for key, value in query {
            // Recursively prepare logical query clauses
            if in_array(key, ["and", "or", "nor"]) && typeof value == "array" {
                for k2, v2 in value {
                    let preparedQuery[key][k2] = this->prepareQueryOrNewObj(v2);
                }
                continue;
            }

            if isset key[0] && key[0] === "" && typeof value == "array" {
                let preparedQuery[key] = this->prepareQueryOrNewObj(value);
                continue;
            }

            let list = this->prepareQueryElement(key, value, null, true);
            let key = list[0];
            let value = list[1];

            let preparedQuery[key] = typeof value == "array"
                ? array_map("Doctrine\ODM\MongoDB\Types\Type::convertPHPToDatabaseValue", value)
                : Type::convertPHPToDatabaseValue(value);
        }

        return preparedQuery;
    }

    /**
     * Prepares a query value and converts the PHP value to the database value
     * if it is an identifier.
     *
     * It also handles converting fieldName to the database name if they are different.
     *
     * @param string fieldName
     * @param mixed value
     * @param ClassMetadata class        Defaults to this->class
     * @param boolean prepareValue Whether or not to prepare the value
     * @return array        Prepared field name and value
     */
    private function prepareQueryElement(fieldName, value = null, class1 = null, prepareValue = true)
    {
        var k2, v2, e, mapping, targetClass, objectProperty, objectPropertyPrefix, nextObjectProperty,
            targetMapping, objectPropertyIsId, nextTargetClass, list, key, k, v;

        let class1 = class1 ? class1 : this->class1;

        // @todo Consider inlining calls to ClassMetadataInfo methods

        // Process all non-identifier fields by translating field names
        if class1->hasField(fieldName) && !class1->isIdentifier(fieldName) {
            let mapping = class1->fieldMappings[fieldName];
            let fieldName = mapping["name"];

            if  !prepareValue {
                return [fieldName, value];
            }

            // Prepare mapped, embedded objects
            if  !empty mapping["embedded"] && is_object(value) &&
                ! this->dm->getMetadataFactory()->isTransient(get_class(value)) {
                return [fieldName, this->pb->prepareEmbeddedDocumentValue(mapping, value)];
            }

            // No further preparation unless we"re dealing with a simple reference
            if empty mapping["reference"] || empty mapping["simple"] {
                return [fieldName, value];
            }

            // Additional preparation for one or more simple reference values
            let targetClass = this->dm->getClassMetadata(mapping["targetDocument"]);

            if  typeof value != "array" {
                return [fieldName, targetClass->getDatabaseIdentifierValue(value)];
            }

            // Objects without operators or with DBRef fields can be converted immediately
            if  !this->hasQueryOperators(value) || this->hasDBRefFields(value) {
                return [fieldName, targetClass->getDatabaseIdentifierValue(value)];
            }

            return [fieldName, this->prepareQueryExpression(value, targetClass)];
        }

        // Process identifier fields
        if (class1->hasField(fieldName) && class1->isIdentifier(fieldName)) || fieldName === "_id" {
            let fieldName = "_id";

            if  ! prepareValue {
                return [fieldName, value];
            }

            if  ! is_array(value) {
                return [fieldName, class1->getDatabaseIdentifierValue(value)];
            }

            // Objects without operators or with DBRef fields can be converted immediately
            if  ! this->hasQueryOperators(value) || this->hasDBRefFields(value) {
                return [fieldName, class1->getDatabaseIdentifierValue(value)];
            }

            return [fieldName, this->prepareQueryExpression(value, class1)];
        }

        // No processing for unmapped, non-identifier, non-dotted field names
        if strpos(fieldName, ".") === false {
            return [fieldName, value];
        }

        /* Process "fieldName.objectProperty" queries (on arrays or objects).
         *
         * We can limit parsing here, since at most three segments are
         * significant: "fieldName.objectProperty" with an optional index or key
         * for collections stored as either BSON arrays or objects.
         */
        let e = explode(".", fieldName, 4);

        // No further processing for unmapped fields
        if  !isset class1->fieldMappings[e[0]] {
            return [fieldName, value];
        }

        let mapping = class1->fieldMappings[e[0]];
        let e[0] = mapping["name"];

        // Hash and raw fields will not be prepared beyond the field name
        if mapping["type"] === Type::HASH || mapping["type"] === Type::RAW {
            let fieldName = implode(".", e);

            return [fieldName, value];
        }

        if mapping["strategy"] === "set" && isset e[2] {
            let objectProperty = e[2];
            let objectPropertyPrefix = e[1] . ".";
            let nextObjectProperty = implode(".", array_slice(e, 3));
        } else {
            if e[1] != "" {
                let fieldName = e[0] . "." . e[1];
                let objectProperty = e[1];
                let objectPropertyPrefix = "";
                let nextObjectProperty = implode(".", array_slice(e, 2));
            } else {
                if isset e[2] {
                    let fieldName = e[0] . "." . e[1] . "." . e[2];
                    let objectProperty = e[2];
                    let objectPropertyPrefix = e[1] . ".";
                    let nextObjectProperty = implode(".", array_slice(e, 3));
                } else {
                    let fieldName = e[0] . "." . e[1];
                    return [fieldName, value];
                }
            }
        }
        

        // No further processing for fields without a targetDocument mapping
        if  !isset mapping["targetDocument"] {
            if nextObjectProperty {
                let fieldName .= ".".nextObjectProperty;
            }

            return [fieldName, value];
        }

        let targetClass = this->dm->getClassMetadata(mapping["targetDocument"]);

        // No further processing for unmapped targetDocument fields
        if  !targetClass->hasField(objectProperty) {
            if nextObjectProperty {
                let fieldName .= ".".nextObjectProperty;
            }

            return [fieldName, value];
        }

        let targetMapping = targetClass->getFieldMapping(objectProperty);
        let objectPropertyIsId = targetClass->isIdentifier(objectProperty);

        // Prepare DBRef identifiers or the mapped field"s property path
        let fieldName = (objectPropertyIsId && ! empty mapping["reference"] && empty mapping["simple"] )
            ? e[0] . ".id"
            : e[0] . "." . objectPropertyPrefix . targetMapping["name"];

        // Process targetDocument identifier fields
        if objectPropertyIsId {
            if  ! prepareValue {
                return [fieldName, value];
            }

            if  typeof value != "array" {
                return [fieldName, targetClass->getDatabaseIdentifierValue(value)];
            }

            // Objects without operators or with DBRef fields can be converted immediately
            if  ! this->hasQueryOperators(value) || this->hasDBRefFields(value) {
                return [fieldName, targetClass->getDatabaseIdentifierValue(value)];
            }

            return [fieldName, this->prepareQueryExpression(value, targetClass)];
        }

        /* The property path may include a third field segment, excluding the
         * collection item pointer. If present, this next object property must
         * be processed recursively.
         */
        if nextObjectProperty {
            // Respect the targetDocument"s class metadata when recursing
            let nextTargetClass = isset targetMapping["targetDocument"]
                ? this->dm->getClassMetadata(targetMapping["targetDocument"])
                : null;

            let list = this->prepareQueryElement(nextObjectProperty, value, nextTargetClass, prepareValue);
            let key = list[0] ;
            let value = list[1] ;
            let fieldName .= "." . key;
        }

        return [fieldName, value];
    }

    /**
     * Prepares a query expression.
     *
     * @param array|object  expression
     * @param ClassMetadata class
     * @return array
     */
    private function prepareQueryExpression(expression, class1)
    {
        var k, v, k2, v2;

        for k, v in expression {
            // Ignore query operators whose arguments need no type conversion
            if in_array(k, ["exists", "type", "mod", "size"]) {
                continue;
            }

            // Process query operators whose argument arrays need type conversion
            if in_array(k, ["in", "nin", "all"]) && typeof v == "array" {
                for k2, v2 in v {
                    let expression[k][k2] = class1->getDatabaseIdentifierValue(v2);
                }
                continue;
            }

            // Recursively process expressions within a not operator
            if k === "not" && typeof v == "array" {
                let expression[k] = this->prepareQueryExpression(v, class1);
                continue;
            }

            let expression[k] = class1->getDatabaseIdentifierValue(v);
        }

        return expression;
    }

    /**
     * Checks whether the value has DBRef fields.
     *
     * This method doesn"t check if the the value is a complete DBRef object,
     * although it should return true for a DBRef. Rather, we"re checking that
     * the value has one or more fields for a DBref. In practice, this could be
     * elemMatch criteria for matching a DBRef.
     *
     * @param mixed value
     * @return boolean
     */
    private function hasDBRefFields(value)
    {
        var key, a;

        if  typeof value != "array" && typeof value != "object" {
            return false;
        }

        if typeof value == "object" {
            let value = get_object_vars(value);
        }

        for key, a in value {
            if key === "ref" || key === "id" || key === "db" {
                return true;
            }
        }

        return false;
    }

    /**
     * Checks whether the value has query operators.
     *
     * @param mixed value
     * @return boolean
     */
    private function hasQueryOperators(value)
    {
        var key, a;
        if  typeof value != "array" && typeof value != "object" {
            return false;
        }

        if typeof value == "object" {
            let value = get_object_vars(value);
        }

        for key, a in value {
            if isset key[0] && key[0] === "" {
                return true;
            }
        }

        return false;
    }

    /**
     * Gets the array of discriminator values for the given ClassMetadata
     *
     * @param ClassMetadata metadata
     * @return array
     */
    private function getClassDiscriminatorValues( metadata)
    {
        var discriminatorValues, className, key;
        
        let discriminatorValues = [metadata->discriminatorValue];
        for className in metadata->subClasses {
            let key = array_search(className, metadata->discriminatorMap);
            if key {
                let discriminatorValues[] = key;
            }
        }
        return discriminatorValues;
    }
}