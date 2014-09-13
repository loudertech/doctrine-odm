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

use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;
use Doctrine\Common\EventManager;
use Doctrine\Common\NotifyPropertyChanged;
use Doctrine\Common\PropertyChangedListener;
use Doctrine\MongoDB\GridFSFile;
use Doctrine\ODM\MongoDB\Event\LifecycleEventArgs;
use Doctrine\ODM\MongoDB\Event\PreLoadEventArgs;
use Doctrine\ODM\MongoDB\Hydrator\HydratorFactory;
use Doctrine\ODM\MongoDB\Internal\CommitOrderCalculator;
use Doctrine\ODM\MongoDB\Mapping\ClassMetadata;
use Doctrine\ODM\MongoDB\PersistentCollection;
use Doctrine\ODM\MongoDB\Persisters\PersistenceBuilder;
use Doctrine\ODM\MongoDB\Proxy\Proxy;
use Doctrine\ODM\MongoDB\Query\Query;
use Doctrine\ODM\MongoDB\Types\Type;

/**
 * The UnitOfWork is responsible for tracking changes to objects during an
 * "object-level" transaction and for writing out changes to the database
 * in the correct order.
 *
 * @since       1.0
 * @author      Jonathan H. Wage <jonwage@gmail.com>
 * @author      Roman Borschel <roman@code-factory.org>
 */
class UnitOfWork implements PropertyChangedListener
{
    /**
     * A document is in MANAGED state when its persistence is managed by a DocumentManager.
     */
    const STATE_MANAGED = 1;

    /**
     * A document is new if it has just been instantiated (i.e. using the "new" operator)
     * and is not (yet) managed by a DocumentManager.
     */
    const STATE_NEW = 2;

    /**
     * A detached document is an instance with a persistent identity that is not
     * (or no longer) associated with a DocumentManager (and a UnitOfWork).
     */
    const STATE_DETACHED = 3;

    /**
     * A removed document instance is an instance with a persistent identity,
     * associated with a DocumentManager, whose persistent state has been
     * deleted (or is scheduled for deletion).
     */
    const STATE_REMOVED = 4;

    /**
     * The identity map holds references to all managed documents.
     *
     * Documents are grouped by their class1name, and then indexed by the
     * serialized string of their database identifier field or, if the class
     * has no identifier, the SPL object hash. Serializing the identifier allows
     * differentiation of values that may be equal (via type juggling) but not
     * identical.
     *
     * Since all classes in a hierarchy must share the same identifier set,
     * we always take the root class1name of the hierarchy.
     *
     * @var array
     */
    private identityMap = [];

    /**
     * Map of all identifiers of managed documents.
     * Keys are object ids (spl_object_hash).
     *
     * @var array
     */
    private documentIdentifiers = [];

    /**
     * Map of the original document data of managed documents.
     * Keys are object ids (spl_object_hash). This is used for calculating changesets
     * at commit time.
     *
     * @var array
     * @internal Note that PHPs "copy-on-write" behavior helps a lot with memory usage.
     *           A value will only really be copied if the value in the document is modified
     *           by the user.
     */
    private originalDocumentData = [];

    /**
     * Map of document changes. Keys are object ids (spl_object_hash).
     * Filled at the beginning of a commit of the UnitOfWork and cleaned at the end.
     *
     * @var array
     */
    private documentChangeSets = [];

    /**
     * The (cached) states of any known documents.
     * Keys are object ids (spl_object_hash).
     *
     * @var array
     */
    private documentStates = [];

    /**
     * Map of documents that are scheduled for dirty checking at commit time.
     *
     * Documents are grouped by their class1name, and then indexed by their SPL
     * object hash. This is only used for documents with a change tracking
     * policy of DEFERRED_EXPLICIT.
     *
     * @var array
     * @todo rename: scheduledForSynchronization
     */
    private scheduledForDirtyCheck = [];

    /**
     * A list of all pending document insertions.
     *
     * @var array
     */
    private documentInsertions = [];

    /**
     * A list of all pending document updates.
     *
     * @var array
     */
    private documentUpdates = [];

    /**
     * A list of all pending document upserts.
     *
     * @var array
     */
    private documentUpserts = [];

    /**
     * Any pending extra updates that have been scheduled by persisters.
     *
     * @var array
     */
    private extraUpdates = [];

    /**
     * A list of all pending document deletions.
     *
     * @var array
     */
    private documentDeletions = [];

    /**
     * All pending collection deletions.
     *
     * @var array
     */
    private collectionDeletions = [];

    /**
     * All pending collection updates.
     *
     * @var array
     */
    private collectionUpdates = [];

    /**
     * List of collections visited during changeset calculation on a commit-phase of a UnitOfWork.
     * At the end of the UnitOfWork all these collections will make new snapshots
     * of their data.
     *
     * @var array
     */
    private visitedCollections = [];

    /**
     * The DocumentManager that "owns" this UnitOfWork instance.
     *
     * @var DocumentManager
     */
    private dm;

    /**
     * The calculator used to calculate the order in which changes to
     * documents need to be written to the database.
     *
     * @var Internal\CommitOrderCalculator
     */
    private commitOrderCalculator;

    /**
     * The EventManager used for dispatching events.
     *
     * @var EventManager
     */
    private evm;

    /**
     * Embedded documents that are scheduled for removal.
     *
     * @var array
     */
    private orphanRemovals = [];

    /**
     * The HydratorFactory used for hydrating array Mongo documents to Doctrine object documents.
     *
     * @var HydratorFactory
     */
    private hydratorFactory;

    /**
     * The document persister instances used to persist document instances.
     *
     * @var array
     */
    private persisters = [];

    /**
     * The collection persister instance used to persist changes to collections.
     *
     * @var Persisters\CollectionPersister
     */
    private collectionPersister;

    /**
     * The persistence builder instance used in DocumentPersisters.
     *
     * @var PersistenceBuilder
     */
    private persistenceBuilder;

    /**
     * Array of parent associations between embedded documents
     *
     * @todo We might need to clean up this array in clear(), doDetach(), etc.
     * @var array
     */
    private parentAssociations = [];

    /**
     * Initializes a new UnitOfWork instance, bound to the given DocumentManager.
     *
     * @param DocumentManager dm
     * @param EventManager evm
     * @param HydratorFactory hydratorFactory
     */
    public function __construct( dm,  evm,  hydratorFactory)
    {
        let this->dm = dm;
        let this->evm = evm;
        let this->hydratorFactory = hydratorFactory;
    }

    /**
     * Factory for returning new PersistenceBuilder instances used for preparing data into
     * queries for insert persistence.
     *
     * @return PersistenceBuilder pb
     */
    public function getPersistenceBuilder()
    {
        if  ! this->persistenceBuilder {
            let this->persistenceBuilder = new PersistenceBuilder(this->dm, this);
        }
        return this->persistenceBuilder;
    }

    /**
     * Sets the parent association for a given embedded document.
     *
     * @param object document
     * @param array mapping
     * @param object parent
     * @param string propertyPath
     */
    public function setParentAssociation(document, mapping, parent, propertyPath)
    {
        var oid;

        let oid = spl_object_hash(document);
        let this->parentAssociations[oid] = [mapping, parent, propertyPath];
    }

    /**
     * Gets the parent association for a given embedded document.
     *
     *     <code>
     *     list(mapping, parent, propertyPath) = this->getParentAssociation(embeddedDocument);
     *     </code>
     *
     * @param object document
     * @return array association
     */
    public function getParentAssociation(document)
    {
        var oid;

        let oid = spl_object_hash(document);
        if  ! isset this->parentAssociations[oid] {
            return null;
        }
        return this->parentAssociations[oid];
    }

    /**
     * Get the document persister instance for the given document name
     *
     * @param string documentName
     * @return Persisters\DocumentPersister
     */
    public function getDocumentPersister(documentName)
    {
        var class1, pb;

        if  ! isset this->persisters[documentName] {
            let class1= this->dm->getClassMetadata(documentName);
            let pb = this->getPersistenceBuilder();
            let this->persisters[documentName] = new Persisters\DocumentPersister(pb, this->dm, this->evm, this, this->hydratorFactory, class1);
        }
        return this->persisters[documentName];
    }

    /**
     * Get the collection persister instance.
     *
     * @return \Doctrine\ODM\MongoDB\Persisters\CollectionPersister
     */
    public function getCollectionPersister()
    {
        var pb;

        if  ! isset this->collectionPersister {
            let pb = this->getPersistenceBuilder();
            let this->collectionPersister = new Persisters\CollectionPersister(this->dm, pb, this);
        }
        return this->collectionPersister;
    }

    /**
     * Set the document persister instance to use for the given document name
     *
     * @param string documentName
     * @param Persisters\DocumentPersister persister
     */
    public function setDocumentPersister(documentName, persister)
    {
        let this->persisters[documentName] = persister;
    }

    /**
     * Commits the UnitOfWork, executing all operations that have been postponed
     * up to this point. The state of all managed documents will be synchronized with
     * the database.
     *
     * The operations are executed in the following order:
     *
     * 1) All document insertions
     * 2) All document updates
     * 3) All document deletions
     *
     * @param object document
     * @param array options Array of options to be used with batchInsert(), update() and remove()
     */
    public function commit(document = null, array options = [])
    {
        var defaultOptions, object1, removal, commitOrder, class1, collectionToDelete,
            collectionToUpdate, i, coll;

        // Raise preFlush
        if this->evm->hasListeners(Events::PREFLUSH) {
            this->evm->dispatchEvent(Events::PREFLUSH, new Event\PreFlushEventArgs(this->dm));
        }

        let defaultOptions = this->dm->getConfiguration()->getDefaultCommitOptions();
        if count(options) > 0 {
            let options = array_merge(defaultOptions, options);
        } else {
            let options = defaultOptions;
        }
        // Compute changes done since last commit.
        if document === null {
            this->computeChangeSets();
        } else {
            if is_object(document) {
                this->computeSingleDocumentChangeSet(document);
            } else {
                if is_array(document) {
                    for object1 in document {
                        this->computeSingleDocumentChangeSet(object1);
                    }
                }
            }
        }

        if  ! (this->documentInsertions ||
            this->documentUpserts ||
            this->documentDeletions ||
            this->documentUpdates ||
            this->collectionUpdates ||
            this->collectionDeletions ||
            this->orphanRemovals)
         {
            return; // Nothing to do.
        }

        if this->orphanRemovals {
            for removal in this->orphanRemovals {
                this->remove(removal);
            }
        }

        // Raise onFlush
        if this->evm->hasListeners(Events::ONFLUSH) {
            this->evm->dispatchEvent(Events::ONFLUSH, new Event\OnFlushEventArgs(this->dm));
        }

        // Now we need a commit order to maintain referential integrity
        let commitOrder = this->getCommitOrder();

        if this->documentUpserts {
            for class1 in commitOrder {
                if class1->isEmbeddedDocument {
                    continue;
                }
                this->executeUpserts(class1, options);
            }
        }

        if this->documentInsertions {
            for class1 in commitOrder {
                if class1->isEmbeddedDocument {
                    continue;
                }
                this->executeInserts(class1, options);
            }
        }

        if this->documentUpdates {
            for class1 in commitOrder {
                this->executeUpdates(class1, options);
            }
        }

        // Extra updates that were requested by persisters.
        if this->extraUpdates {
            this->executeExtraUpdates(options);
        }

        // Collection deletions (deletions of complete collections)
        for collectionToDelete in this->collectionDeletions {
            this->getCollectionPersister()->delete(collectionToDelete, options);
        }
        // Collection updates (deleteRows, updateRows, insertRows)
        for collectionToUpdate in this->collectionUpdates {
            this->getCollectionPersister()->update(collectionToUpdate, options);
        }

        // Document deletions come last and need to be in reverse commit order
        if this->documentDeletions {

            let i = count(commitOrder) - 1;
            while i >= 0 {
                let i -= 1;
                this->executeDeletions(commitOrder[i], options);
            }
            /*for (count = count(commitOrder), i = count - 1; i >= 0; --i {
                this->executeDeletions(commitOrder[i], options);
            }*/

        }

        // Take new snapshots from visited collections
        for coll in this->visitedCollections {
            coll->takeSnapshot();
        }

        // Raise postFlush
        if this->evm->hasListeners(Events::POSTFLUSH) {
            this->evm->dispatchEvent(Events::POSTFLUSH, new Event\PostFlushEventArgs(this->dm));
        }

        // Clear up
        let this->documentInsertions = "";
        let this->documentUpserts = "";
        let this->documentUpdates = "";
        let this->documentDeletions = "";
        let this->extraUpdates = "";
        let this->documentChangeSets = "";
        let this->collectionUpdates = "";
        let this->collectionDeletions = "";
        let this->visitedCollections = "";
        let this->scheduledForDirtyCheck = "";
        let this->orphanRemovals = [];
    }

    /**
     * Compute changesets of all documents scheduled for insertion.
     *
     * Embedded documents will not be processed.
     */
    private function computeScheduleInsertsChangeSets()
    {
        var document, class1;

        for document in this->documentInsertions {
            let class1 = this->dm->getClassMetadata(get_class(document));

            if class1->isEmbeddedDocument {
                continue;
            }

            this->computeChangeSet(class1, document);
        }
    }

    /**
     * Compute changesets of all documents scheduled for upsert.
     *
     * Embedded documents will not be processed.
     */
    private function computeScheduleUpsertsChangeSets()
    {
        var document, class1;
        for document in this->documentUpserts {
            let class1 = this->dm->getClassMetadata(get_class(document));

            if class1->isEmbeddedDocument {
                continue;
            }

            this->computeChangeSet(class1, document);
        }
    }

    /**
     * Only flush the given document according to a ruleset that keeps the UoW consistent.
     *
     * 1. All documents scheduled for insertion, (orphan) removals and changes in collections are processed as well!
     * 2. Proxies are skipped.
     * 3. Only if document is properly managed.
     *
     * @param  object document
     * @throws \InvalidArgumentException If the document is not STATE_MANAGED
     * @return void
     */
    private function computeSingleDocumentChangeSet(document)
    {
        var state, oid, class1, name;

        let state = this->getDocumentState(document);

        if state !== self::STATE_MANAGED && state !== self::STATE_REMOVED {
            throw new \InvalidArgumentException("Document has to be managed or scheduled for removal for single computation " . self::objToStr(document));
        }

        let class1 = this->dm->getClassMetadata(get_class(document));

        if state === self::STATE_MANAGED && class1->isChangeTrackingDeferredImplicit() {
            this->persist(document);
        }

        // Compute changes for INSERTed and UPSERTed documents first. This must always happen even in this case.
        this->computeScheduleInsertsChangeSets();
        this->computeScheduleUpsertsChangeSets();

        // Ignore uninitialized proxy objects
        if (document instanceof Proxy) && ! document->__isInitialized__ {
            return;
        }

        // Only MANAGED documents that are NOT SCHEDULED FOR INSERTION, UPSERT OR DELETION are processed here.
        let oid = spl_object_hash(document);

        if  ! isset this->documentInsertions[oid]
            && ! isset this->documentUpserts[oid]
            && ! isset this->documentDeletions[oid]
            && isset this->documentStates[oid]
         {
            this->computeChangeSet(class1, document);
        }
    }

    /**
     * Executes reference updates
     */
    private function executeExtraUpdates(array options)
    {
        var oid, update, list, document, changeset;

        for oid, update in this->extraUpdates {
            let list = update;
            let document = update[0];
            let changeset = update[1];
            let this->documentChangeSets[oid] = changeset;
            this->getDocumentPersister(get_class(document))->update(document, options);
        }
    }

    /**
     * Gets the changeset for a document.
     *
     * @param object document
     * @return array
     */
    public function getDocumentChangeSet(document)
    {
        var oid;

        let oid = spl_object_hash(document);
        if isset this->documentChangeSets[oid] {
            return this->documentChangeSets[oid];
        }
        return [];
    }

    /**
     * Get a documents actual data, flattening all the objects to arrays.
     *
     * @param object document
     * @return array
     */
    public function getDocumentActualData(document)
    {
        var class1, actualData, refProp, mapping, value, coll;

        let class1 = this->dm->getClassMetadata(get_class(document));
        let actualData = [];
        for refProp in class1->reflFields {
            let mapping = class1->fieldMappings[refProp];
            // skip not saved fields
            if isset mapping["notSaved"] && mapping["notSaved"] === true {
                continue;
            }
            let value = refProp->getValue(document);
            if isset mapping["file"] && ! (value instanceof GridFSFile) {
                let value = new GridFSFile(value);
                class1->reflFields[refProp]->setValue(document, value);
                let actualData[refProp] = value;
            } else {
                if (isset mapping["association"] && mapping["type"] === "many")
                    && value !== null && ! (value instanceof PersistentCollection) {
                    // If actualData[name] is not a Collection then use an ArrayCollection.
                    if  ! (value instanceof Collection) {
                        let value = new ArrayCollection(value);
                    }

                    // Inject PersistentCollection
                    let coll = new PersistentCollection(value, this->dm, this);
                    coll->setOwner(document, mapping);
                    coll->setDirty( ! value->isEmpty());
                    class1->reflFields[refProp]->setValue(document, coll);
                    let actualData[refProp] = coll;
                } else {
                    let actualData[refProp] = value;
                }
            }
        }
        return actualData;
    }

    /**
     * Computes the changes that happened to a single document.
     *
     * Modifies/populates the following properties:
     *
     * {@link originalDocumentData}
     * If the document is NEW or MANAGED but not yet fully persisted (only has an id)
     * then it was not fetched from the database and therefore we have no original
     * document data yet. All of the current document data is stored as the original document data.
     *
     * {@link documentChangeSets}
     * The changes detected on all properties of the document are stored there.
     * A change is a tuple array where the first entry is the old value and the second
     * entry is the new value of the property. Changesets are used by persisters
     * to INSERT/UPDATE the persistent document state.
     *
     * {@link documentUpdates}
     * If the document is already fully MANAGED (has been fetched from the database before)
     * and any changes to its properties are detected, then a reference to the document is stored
     * there to mark it for an update.
     *
     * @param ClassMetadata class1The class1descriptor of the document.
     * @param object document The document for which to compute the changes.
     */
    public function computeChangeSet( class1, document)
    {

        if  ! class1->isInheritanceTypeNone() {
            let class1 = this->dm->getClassMetadata(get_class(document));
        }

        // Fire PreFlush lifecycle callbacks
        if  ! empty class1->lifecycleCallbacks[Events::PREFLUSH] {
            class1->invokeLifecycleCallbacks(Events::PREFLUSH, document);
        }

        this->computeOrRecomputeChangeSet(class1, document);
    }

    /**
     * Used to do the common work of computeChangeSet and recomputeSingleDocumentChangeSet
     *
     * @param \Doctrine\ODM\MongoDB\Mapping\ClassMetadata class
     * @param object document
     * @param boolean recompute
     */
    private function computeOrRecomputeChangeSet( class1, document, recompute = false)
    {
        var oid, actualData, isNewDocument, changeSet, propName, actualValue, originalData, isChangeTrackingNotify,
            orgValue, owner, newValue, dateType, dbOrgValue, dbActualValue, mapping, value, obj, values, oid2;

        let oid = spl_object_hash(document);
        let actualData = this->getDocumentActualData(document);
        let isNewDocument = !isset this->originalDocumentData[oid];
        if isNewDocument {
            // Document is either NEW or MANAGED but not yet fully persisted (only has an id).
            // These result in an INSERT.
            let this->originalDocumentData[oid] = actualData;
            let changeSet = [];
            for propName, actualValue in actualData {
                let changeSet[propName] = [null, actualValue];
            }
            let this->documentChangeSets[oid] = changeSet;
        } else {
            // Document is "fully" MANAGED: it was already fully persisted before
            // and we have a copy of the original data
            let originalData = this->originalDocumentData[oid];
            let isChangeTrackingNotify = class1->isChangeTrackingNotify();
            if isChangeTrackingNotify && ! recompute {
                let changeSet = this->documentChangeSets[oid];
            } else {
                let changeSet = [];
            }

            for propName, actualValue in actualData {
                // skip not saved fields
                if isset class1->fieldMappings[propName]["notSaved"] && class1->fieldMappings[propName]["notSaved"] === true {
                    continue;
                }

                let orgValue = isset originalData[propName] ? originalData[propName] : null;

                // skip if value has not changed
                if orgValue === actualValue {
                    // but consider dirty GridFSFile instances as changed
                    if  ! (isset class1->fieldMappings[propName]["file"] && actualValue->isDirty()) {
                        continue;
                    }
                }

                // if relationship is a embed-one, schedule orphan removal to trigger cascade remove operations
                if isset class1->fieldMappings[propName]["embedded"] && class1->fieldMappings[propName]["type"] === "one" {
                    if orgValue !== null {
                        this->scheduleOrphanRemoval(orgValue);
                    }

                    let changeSet[propName] = [orgValue, actualValue];
                    continue;
                }

                // if owning side of reference-one relationship
                if isset class1->fieldMappings[propName]["reference"] && class1->fieldMappings[propName]["type"] === "one" && class1->fieldMappings[propName]["isOwningSide"] {
                    if orgValue !== null && class1->fieldMappings[propName]["orphanRemoval"] {
                        this->scheduleOrphanRemoval(orgValue);
                    }

                    let changeSet[propName] = [orgValue, actualValue];
                    continue;
                }

                if isChangeTrackingNotify {
                    continue;
                }

                // ignore inverse side of reference-many relationship
                if isset class1->fieldMappings[propName]["reference"] && class1->fieldMappings[propName]["type"] === "many" && class1->fieldMappings[propName]["isInverseSide"] {
                    continue;
                }

                // Persistent collection was exchanged with the "originally"
                // created one. This can only mean it was cloned and replaced
                // on another document.
                if (actualValue instanceof PersistentCollection) {
                    let owner = actualValue->getOwner();
                    if owner === null { // cloned
                        actualValue->setOwner(document, class1->fieldMappings[propName]);
                    } else {
                        if owner !== document { // no clone, we have to fix
                            if  ! actualValue->isInitialized() {
                                actualValue->initialize(); // we have to do this otherwise the cols share state
                            }
                            let newValue = clone actualValue;
                            newValue->setOwner(document, class1->fieldMappings[propName]);
                            class1->reflFields[propName]->setValue(document, newValue);
                        }
                    }
                }

                // if embed-many or reference-many relationship
                if isset class1->fieldMappings[propName]["type"] && class1->fieldMappings[propName]["type"] === "many" {
                    let changeSet[propName] = [orgValue, actualValue];
                    if (orgValue instanceof PersistentCollection) {
                        let this->collectionDeletions[] = orgValue;
                    }
                    continue;
                }

                // skip equivalent date values
                if isset class1->fieldMappings[propName]["type"] && class1->fieldMappings[propName]["type"] === "date" {
                    let dateType = Type::getType("date");
                    let dbOrgValue = dateType->convertToDatabaseValue(orgValue);
                    let dbActualValue = dateType->convertToDatabaseValue(actualValue);

                    if (dbOrgValue instanceof \MongoDate) && (dbActualValue instanceof \MongoDate) && dbOrgValue == dbActualValue {
                        continue;
                    }
                }

                // regular field
                let changeSet[propName] = [orgValue, actualValue];
            }
            if changeSet {
                let this->documentChangeSets[oid] = (recompute && isset this->documentChangeSets[oid])
                    ? changeSet + this->documentChangeSets[oid]
                    : changeSet;

                let this->originalDocumentData[oid] = actualData;
                let this->documentUpdates[oid] = document;
            }
        }

        // Look for changes in associations of the document
        for mapping in class1->fieldMappings {
            // skip not saved fields
            if isset mapping["notSaved"] && mapping["notSaved"] === true {
                continue;
            }
            if isset mapping["reference"] || isset mapping["embedded"] {
                let value = class1->reflFields[mapping["fieldName"]]->getValue(document);
                if value !== null {
                    this->computeAssociationChanges(document, mapping, value);
                    if isset mapping["reference"] {
                        continue;
                    }

                    let values = value;
                    if isset mapping["type"] && mapping["type"] === "one" {
                        let values = [values];
                    } else { 
                        if (values instanceof PersistentCollection) {
                            let values = values->unwrap();
                        }
                    }
                    for obj in values {
                        let oid2 = spl_object_hash(obj);
                        if isset this->documentChangeSets[oid2] {
                            let this->documentChangeSets[oid][mapping["fieldName"]] = [value, value];
                            if  ! isNewDocument {
                                let this->documentUpdates[oid] = document;
                            }
                            break;
                        }
                    }
                }
            }
        }
    }

    /**
     * Computes all the changes that have been done to documents and collections
     * since the last commit and stores these changes in the _documentChangeSet map
     * temporarily for access by the persisters, until the UoW commit is finished.
     */
    public function computeChangeSets()
    {
        var className, documents, class1, documentsToProcess, oid, document;

        this->computeScheduleInsertsChangeSets();
        this->computeScheduleUpsertsChangeSets();

        // Compute changes for other MANAGED documents. Change tracking policies take effect here.
        for className, documents in this->identityMap {
            let class1 = this->dm->getClassMetadata(className);
            if class1->isEmbeddedDocument {
                // Embedded documents should only compute by the document itself which include the embedded document.
                // This is done separately later.
                // @see computeChangeSet()
                // @see computeAssociationChanges()
                continue;
            }

            // If change tracking is explicit or happens through notification, then only compute
            // changes on documents of that type that are explicitly marked for synchronization.
            let documentsToProcess = ! class1->isChangeTrackingDeferredImplicit() ?
                    (isset this->scheduledForDirtyCheck[className] ?
                        this->scheduledForDirtyCheck[className] : [])
                    : documents;

            for document in documentsToProcess {
                // Ignore uninitialized proxy objects
                if /* document is readOnly || */ (document instanceof Proxy) && ! document->__isInitialized__ {
                    continue;
                }
                // Only MANAGED documents that are NOT SCHEDULED FOR INSERTION, UPSERT OR DELETION are processed here.
                let oid = spl_object_hash(document);
                if  ! isset this->documentInsertions[oid] && ! isset this->documentUpserts[oid] && ! isset this->documentDeletions[oid] && isset this->documentStates[oid] {
                    this->computeChangeSet(class1, document);
                }
            }
        }
    }

    /**
     * Computes the changes of an embedded document.
     *
     * @param object parentDocument
     * @param array mapping
     * @param mixed value The value of the association.
     * @throws \InvalidArgumentException
     */
    private function computeAssociationChanges(parentDocument, mapping, value)
    {
        var isNewDocument, class1, topOrExistingDocument, count, key, entry, targetClass, state,
            path, pathKey, isNewParentDocument; 

        let isNewParentDocument = isset this->documentInsertions[spl_object_hash(parentDocument)];
        let class1 = this->dm->getClassMetadata(get_class(parentDocument));
        let topOrExistingDocument = ( ! isNewParentDocument || ! class1->isEmbeddedDocument);

        if (value instanceof PersistentCollection) && value->isDirty() && mapping["isOwningSide"] {
            if topOrExistingDocument || strncmp(mapping["strategy"], "set", 3) === 0 {
                if  ! in_array(value, this->collectionUpdates, true) {
                    let this->collectionUpdates[] = value;
                }
            }
            let this->visitedCollections[] = value;
        }

        if  ! mapping["isCascadePersist"] {
            return; // "Persistence by reachability" only if persist cascade specified
        }

        if mapping["type"] === "one" {
            if (value instanceof Proxy) && ! value->__isInitialized__ {
                return; // Ignore uninitialized proxy objects
            }
            let value = [value];
        } else {
            if (value instanceof PersistentCollection) {
                let value = value->unwrap();
            }
        }
        let count = 0;
        for key, entry in value {
            let targetClass = this->dm->getClassMetadata(get_class(entry));
            let state = this->getDocumentState(entry, self::STATE_NEW);

            // Handle "set" strategy for multi-level hierarchy
            let pathKey = mapping["strategy"] !== "set" ? count : key;
            let path = mapping["type"] === "many" ? mapping["name"] . "." . pathKey : mapping["name"];

            let count++;
            if state == self::STATE_NEW {
                if  ! mapping["isCascadePersist"] {
                    throw new \InvalidArgumentException("A new document was found through a relationship that was not"
                        . " configured to cascade persist operations: " . self::objToStr(entry) . "."
                        . " Explicitly persist the new document or configure cascading persist operations"
                        . " on the relationship.");
                }
                this->persistNew(targetClass, entry);
                this->setParentAssociation(entry, mapping, parentDocument, path);
                this->computeChangeSet(targetClass, entry);
            } else {
                if state == self::STATE_MANAGED && targetClass->isEmbeddedDocument {
                    this->setParentAssociation(entry, mapping, parentDocument, path);
                    this->computeChangeSet(targetClass, entry);
                } else {
                    if state == self::STATE_REMOVED {
                        throw new \InvalidArgumentException("Removed document detected during flush: "
                            . self::objToStr(entry) . ". Remove deleted documents from associations.");
                    } else {
                        if state == self::STATE_DETACHED {
                            // Can actually not happen right now as we assume STATE_NEW,
                            // so the exception will be raised from the DBAL layer (constraint violation).
                            throw new \InvalidArgumentException("A detached document was found through a "
                                . "relationship during cascading a persist operation.");
                        }
                    }
                }
            }
        }
    }

    /**
     * INTERNAL:
     * Computes the changeset of an individual document, independently of the
     * computeChangeSets() routine that is used at the beginning of a UnitOfWork#commit().
     *
     * The passed document must be a managed document. If the document already has a change set
     * because this method is invoked during a commit cycle then the change sets are added.
     * whereby changes detected in this method prevail.
     *
     * @ignore
     * @param ClassMetadata class1The class1descriptor of the document.
     * @param object document The document for which to (re)calculate the change set.
     * @throws \InvalidArgumentException If the passed document is not MANAGED.
     */
    public function recomputeSingleDocumentChangeSet( class1, document)
    {
        var oid;

        let oid = spl_object_hash(document);

        if  ! isset this->documentStates[oid] || this->documentStates[oid] != self::STATE_MANAGED {
            throw new \InvalidArgumentException("Document must be managed.");
        }

        if  ! class1->isInheritanceTypeNone() {
            let class1 = this->dm->getClassMetadata(get_class(document));
        }

        this->computeOrRecomputeChangeSet(class1, document, true);
    }

    /**
     * @param class
     * @param object document
     */
    private function persistNew(class1, document)
    {
        var oid, upsert, idValue;

        let oid = spl_object_hash(document);
        if  ! empty(class1->lifecycleCallbacks[Events::PREPERSIST]) {
            class1->invokeLifecycleCallbacks(Events::PREPERSIST, document);
        }
        if this->evm->hasListeners(Events::PREPERSIST) {
            this->evm->dispatchEvent(Events::PREPERSIST, new LifecycleEventArgs(document, this->dm));
        }

        let upsert = false;
        if class1->identifier {
            let idValue = class1->getIdentifierValue(document);
            let upsert = !class1->isEmbeddedDocument && idValue !== null;

            if class1->generatorType !== ClassMetadata::GENERATOR_TYPE_NONE && idValue === null {
                let idValue = class1->idGenerator->generate(this->dm, document);
                let idValue = class1->getPHPIdentifierValue(class1->getDatabaseIdentifierValue(idValue));
                class1->setIdentifierValue(document, idValue);
            }

            let this->documentIdentifiers[oid] = idValue;
        }

        let this->documentStates[oid] = self::STATE_MANAGED;

        if upsert {
            this->scheduleForUpsert(class1, document);
        } else {
            this->scheduleForInsert(class1, document);
        }
    }

    /**
     * Executes all document insertions for documents of the specified type.
     *
     * @param ClassMetadata class
     * @param array options Array of options to be used with batchInsert()
     */
    private function executeInserts(class1, array options = [])
    {
        var className,persister, collection, insertedDocuments, oid, document, id,
            hasPostPersistLifecycleCallbacks, hasPostPersistListeners;
        let className = class1->name;
        let persister = this->getDocumentPersister(className);
        let collection = this->dm->getDocumentCollection(className);

        let insertedDocuments = [];

        for oid, document in this->documentInsertions {
            if get_class(document) === className {
                persister->addInsert(document);
                let insertedDocuments[] = document;
                unset(this->documentInsertions[oid]);
            }
        }

        persister->executeInserts(options);

        for document in insertedDocuments {
            let id = class1->getIdentifierValue(document);

            /* Inline call to UnitOfWork::registerManager(), but only update the
             * identifier in the original document data.
             */
            let oid = spl_object_hash(document);
            let this->documentIdentifiers[oid] = id;
            let this->documentStates[oid] = self::STATE_MANAGED;
            let this->originalDocumentData[oid][class1->identifier] = id;
            this->addToIdentityMap(document);
        }

        let hasPostPersistLifecycleCallbacks = ! empty class1->lifecycleCallbacks[Events::POSTPERSIST];
        let hasPostPersistListeners = this->evm->hasListeners(Events::POSTPERSIST);

        for document in insertedDocuments {
            if hasPostPersistLifecycleCallbacks {
                class1->invokeLifecycleCallbacks(Events::POSTPERSIST, document);
            }
            if hasPostPersistListeners {
                this->evm->dispatchEvent(Events::POSTPERSIST, new LifecycleEventArgs(document, this->dm));
            }
            this->cascadePostPersist(class1, document);
        }
    }

    /**
     * Executes all document upserts for documents of the specified type.
     *
     * @param ClassMetadata class
     * @param array options Array of options to be used with batchInsert()
     */
    private function executeUpserts(class1, array options = [])
    {
        var oid, className,persister, collection, hasLifecycleCallbacks, hasListeners, upsertedDocuments,
            document;

        let className = class1->name;
        let persister = this->getDocumentPersister(className);
        let collection = this->dm->getDocumentCollection(className);

        let upsertedDocuments = [];

        for oid, document in this->documentUpserts {
            if get_class(document) === className {
                persister->addUpsert(document);
                let upsertedDocuments[] = document;
                unset(this->documentUpserts[oid]);
            }
        }

        persister->executeUpserts(options);

        let hasLifecycleCallbacks = isset class1->lifecycleCallbacks[Events::POSTPERSIST];
        let hasListeners = this->evm->hasListeners(Events::POSTPERSIST);

        for document in upsertedDocuments {
            if hasLifecycleCallbacks {
                class1->invokeLifecycleCallbacks(Events::POSTPERSIST, document);
            }
            if hasListeners {
                this->evm->dispatchEvent(Events::POSTPERSIST, new LifecycleEventArgs(document, this->dm));
            }
            this->cascadePostPersist(class1, document);
        }
    }

    /**
     * Cascades the postPersist events to embedded documents.
     *
     * @param ClassMetadata class
     * @param object document
     */
    private function cascadePostPersist(class1, document)
    {
        var hasPostPersistListeners, mapping, value, embeddedClass, embeddedDocument;

        let hasPostPersistListeners = this->evm->hasListeners(Events::POSTPERSIST);

        for mapping in class1->fieldMappings {
            if empty mapping["embedded"] {
                continue;
            }

            let value = class1->reflFields[mapping["fieldName"]]->getValue(document);

            if value === null {
                continue;
            }

            if mapping["type"] === "one" {
                let value = [value];
            }

            if isset mapping["targetDocument"] {
                let embeddedClass = this->dm->getClassMetadata(mapping["targetDocument"]);
            }

            for embeddedDocument in value {
                if  ! isset mapping["targetDocument"] {
                    let embeddedClass = this->dm->getClassMetadata(get_class(embeddedDocument));
                }

                if  ! empty embeddedClass->lifecycleCallbacks[Events::POSTPERSIST] {
                    embeddedClass->invokeLifecycleCallbacks(Events::POSTPERSIST, embeddedDocument);
                }
                if hasPostPersistListeners {
                    this->evm->dispatchEvent(Events::POSTPERSIST, new LifecycleEventArgs(embeddedDocument, this->dm));
                }
                this->cascadePostPersist(embeddedClass, embeddedDocument);
            }
        }
    }

    /**
     * Executes all document updates for documents of the specified type.
     *
     * @param Mapping\ClassMetadata class
     * @param array options Array of options to be used with update()
     */
    private function executeUpdates(class1, array options = [])
    {
        var className, persister, hasPreUpdateListeners, hasPreUpdateLifecycleCallbacks, hasPostUpdateLifecycleCallbacks,
            hasPostUpdateListeners, oid, document;

        let className = class1->name;
        let persister = this->getDocumentPersister(className);

        let hasPreUpdateLifecycleCallbacks = ! empty class1->lifecycleCallbacks[Events::PREUPDATE];
        let hasPreUpdateListeners = this->evm->hasListeners(Events::PREUPDATE);
        let hasPostUpdateLifecycleCallbacks = ! empty class1->lifecycleCallbacks[Events::POSTUPDATE] ;
        let hasPostUpdateListeners = this->evm->hasListeners(Events::POSTUPDATE);

        for oid, document in this->documentUpdates {
            if get_class(document) == className || (document instanceof Proxy) && (document instanceof className) {
                if  ! class1->isEmbeddedDocument {
                    if hasPreUpdateLifecycleCallbacks {
                        class1->invokeLifecycleCallbacks(Events::PREUPDATE, document);
                        this->recomputeSingleDocumentChangeSet(class1, document);
                    }

                    if hasPreUpdateListeners && isset this->documentChangeSets[oid] {
                        this->evm->dispatchEvent(Events::PREUPDATE, new Event\PreUpdateEventArgs(
                            document, this->dm, this->documentChangeSets[oid])
                        );
                    }
                    this->cascadePreUpdate(class1, document);
                }

                if  ! class1->isEmbeddedDocument && isset this->documentChangeSets[oid] && this->documentChangeSets[oid] {
                    persister->update(document, options);
                }
                unset(this->documentUpdates[oid]);

                if  ! class1->isEmbeddedDocument {
                    if hasPostUpdateLifecycleCallbacks {
                        class1->invokeLifecycleCallbacks(Events::POSTUPDATE, document);
                    }
                    if hasPostUpdateListeners {
                        this->evm->dispatchEvent(Events::POSTUPDATE, new LifecycleEventArgs(document, this->dm));
                    }
                    this->cascadePostUpdateAndPostPersist(class1, document);
                }
            }
        }
    }

    /**
     * Cascades the preUpdate event to embedded documents.
     *
     * @param ClassMetadata class
     * @param object document
     */
    private function cascadePreUpdate(class1, document)
    {
        var hasPreUpdateListeners, mapping, value, entry, entryOid, entryClass;

        let hasPreUpdateListeners = this->evm->hasListeners(Events::PREUPDATE);

        for mapping in class1->fieldMappings {
            if isset mapping["embedded"] {
                let value = class1->reflFields[mapping["fieldName"]]->getValue(document);
                if value === null {
                    continue;
                }
                if mapping["type"] === "one" {
                    let value = [value];
                }
                for entry in value {
                    let entryOid = spl_object_hash(entry);
                    let entryClass = this->dm->getClassMetadata(get_class(entry));
                    if  ! isset this->documentChangeSets[entryOid] {
                        continue;
                    }
                    if  ! isset this->documentInsertions[entryOid] {
                        if  ! empty entryClass->lifecycleCallbacks[Events::PREUPDATE] {
                            entryClass->invokeLifecycleCallbacks(Events::PREUPDATE, entry);
                            this->recomputeSingleDocumentChangeSet(entryClass, entry);
                        }
                        if hasPreUpdateListeners {
                            this->evm->dispatchEvent(Events::PREUPDATE, new Event\PreUpdateEventArgs(
                                entry, this->dm, this->documentChangeSets[entryOid])
                            );
                        }
                    }
                    this->cascadePreUpdate(entryClass, entry);
                }
            }
        }
    }

    /**
     * Cascades the postUpdate and postPersist events to embedded documents.
     *
     * @param ClassMetadata class
     * @param object document
     */
    private function cascadePostUpdateAndPostPersist(class1, document)
    {
        var hasPostPersistListeners, hasPostUpdateListeners, mapping, value, entry, entryOid, entryClass;

        let hasPostPersistListeners = this->evm->hasListeners(Events::POSTPERSIST);
        let hasPostUpdateListeners = this->evm->hasListeners(Events::POSTUPDATE);

        for mapping in class1->fieldMappings {
            if isset mapping["embedded"] {
                let value = class1->reflFields[mapping["fieldName"]]->getValue(document);
                if value === null {
                    continue;
                }
                if mapping["type"] === "one" {
                    let value = [value];
                }
                for entry in value {
                    let entryOid = spl_object_hash(entry);
                    let entryClass = this->dm->getClassMetadata(get_class(entry));
                    if  ! isset this->documentChangeSets[entryOid] {
                        continue;
                    }
                    if isset this->documentInsertions[entryOid] {
                        if  ! empty entryClass->lifecycleCallbacks[Events::POSTPERSIST] {
                            entryClass->invokeLifecycleCallbacks(Events::POSTPERSIST, entry);
                        }
                        if hasPostPersistListeners {
                            this->evm->dispatchEvent(Events::POSTPERSIST, new LifecycleEventArgs(entry, this->dm));
                        }
                    } else {
                        if  ! empty entryClass->lifecycleCallbacks[Events::POSTUPDATE] {
                            entryClass->invokeLifecycleCallbacks(Events::POSTUPDATE, entry);
                            this->recomputeSingleDocumentChangeSet(entryClass, entry);
                        }
                        if hasPostUpdateListeners {
                            this->evm->dispatchEvent(Events::POSTUPDATE, new LifecycleEventArgs(entry, this->dm));
                        }
                    }
                    this->cascadePostUpdateAndPostPersist(entryClass, entry);
                }
            }
        }
    }

    /**
     * Executes all document deletions for documents of the specified type.
     *
     * @param ClassMetadata class
     * @param array options Array of options to be used with remove()
     */
    private function executeDeletions(class1, array options = [])
    {
        var hasPostRemoveListeners, hasPostRemoveLifecycleCallbacks, className, persister, collection, oid,
            document, fieldMapping, value;

        let hasPostRemoveLifecycleCallbacks = ! empty class1->lifecycleCallbacks[Events::POSTREMOVE];
        let hasPostRemoveListeners = this->evm->hasListeners(Events::POSTREMOVE);

        let className = class1->name;
        let persister = this->getDocumentPersister(className);
        let collection = this->dm->getDocumentCollection(className);
        for oid, document in this->documentDeletions {
            if get_class(document) == className || (document instanceof Proxy) && (document instanceof className) {
                if  ! class1->isEmbeddedDocument {
                    persister->delete(document, options);
                }
                unset(this->documentDeletions[oid]);
                unset(this->documentIdentifiers[oid]);
                unset(this->originalDocumentData[oid]);

                // Clear snapshot information for any referenced PersistentCollection
                // http://www.doctrine-project.org/jira/browse/MODM-95
                for fieldMapping in class1->fieldMappings {
                    if isset fieldMapping["type"] && fieldMapping["type"] === "many" {
                        let value = class1->reflFields[fieldMapping["fieldName"]]->getValue(document);
                        if (value instanceof PersistentCollection) {
                            value->clearSnapshot();
                        }
                    }
                }

                // Document with this oid after deletion treated as NEW, even if the oid
                // is obtained by a new document because the old one went out of scope.
                let this->documentStates[oid] = self::STATE_NEW;

                if hasPostRemoveLifecycleCallbacks {
                    class1->invokeLifecycleCallbacks(Events::POSTREMOVE, document);
                }
                if hasPostRemoveListeners {
                    this->evm->dispatchEvent(Events::POSTREMOVE, new LifecycleEventArgs(document, this->dm));
                }
                this->cascadePostRemove(class1, document);
            }
        }
    }

    /**
     * Gets the commit order.
     *
     * @return array
     */
    private function getCommitOrder(documentChangeSet = null)
    {
        var calc, newNodes, document, className, class1, assoc, 
            a, b, c, d, targetClass, subClassName, targetSubClass;

        if documentChangeSet === null {
            let a = this->documentInsertions;
            let b = this->documentUpserts;
            let c = this->documentUpdates;
            let d = this->documentDeletions;
            let documentChangeSet = array_merge( a, b, c, d);
        }

        let calc = this->getCommitOrderCalculator();

        // See if there are any new classes in the changeset, that are not in the
        // commit order graph yet (don"t have a node).
        // We have to inspect changeSet to be able to correctly build dependencies.
        // It is not possible to use IdentityMap here because post inserted ids
        // are not yet available.
        let newNodes = [];

        for document in documentChangeSet {
            let className = get_class(document);

            if calc->hasClass(className) {
                continue;
            }

            let class1 = this->dm->getClassMetadata(className);
            calc->addClass(class1);

            let newNodes[] = class1;
        }

        // Calculate dependencies for new nodes
        loop {
            let class1 = array_pop(newNodes);
            if !class1 { break; }

            for assoc in class1->associationMappings {
                if  ! (assoc["isOwningSide"] && isset assoc["targetDocument"]) {
                    continue;
                }

                let targetClass = this->dm->getClassMetadata(assoc["targetDocument"]);

                if  ! calc->hasClass(targetClass->name) {
                    calc->addClass(targetClass);

                    let newNodes[] = targetClass;
                }

                calc->addDependency(targetClass, class1);

                // If the target class1has mapped subclasses, these share the same dependency.
                if  ! targetClass->subClasses {
                    continue;
                }

                for subClassName in targetClass->subClasses {
                    let targetSubClass = this->dm->getClassMetadata(subClassName);

                    if  ! calc->hasClass(subClassName) {
                        calc->addClass(targetSubClass);

                        let newNodes[] = targetSubClass;
                    }

                    calc->addDependency(targetSubClass, class1);
                }
            }
        }

        return calc->getCommitOrder();
    }

    /**
     * Schedules a document for insertion into the database.
     * If the document already has an identifier, it will be added to the
     * identity map.
     *
     * @param ClassMetadata class
     * @param object document The document to schedule for insertion.
     * @throws \InvalidArgumentException
     */
    public function scheduleForInsert(class1, document)
    {
        var oid;

        let oid = spl_object_hash(document);

        if isset this->documentUpdates[oid] {
            throw new \InvalidArgumentException("Dirty document can not be scheduled for insertion.");
        }
        if isset this->documentDeletions[oid] {
            throw new \InvalidArgumentException("Removed document can not be scheduled for insertion.");
        }
        if isset this->documentInsertions[oid] {
            throw new \InvalidArgumentException("Document can not be scheduled for insertion twice.");
        }

        let this->documentInsertions[oid] = document;

        if isset this->documentIdentifiers[oid] {
            this->addToIdentityMap(document);
        }
    }

    /**
     * Schedules a document for upsert into the database and adds it to the
     * identity map
     *
     * @param ClassMetadata class
     * @param object document The document to schedule for upsert.
     * @throws \InvalidArgumentException
     */
    public function scheduleForUpsert(class1, document)
    {
        var oid;

        let oid = spl_object_hash(document);

        if isset this->documentUpdates[oid] {
            throw new \InvalidArgumentException("Dirty document can not be scheduled for upsert.");
        }
        if isset this->documentDeletions[oid] {
            throw new \InvalidArgumentException("Removed document can not be scheduled for upsert.");
        }
        if isset this->documentUpserts[oid] {
            throw new \InvalidArgumentException("Document can not be scheduled for upsert twice.");
        }

        let this->documentUpserts[oid] = document;
        let this->documentIdentifiers[oid] = class1->getIdentifierValue(document);
        this->addToIdentityMap(document);
    }

    /**
     * Checks whether a document is scheduled for insertion.
     *
     * @param object document
     * @return boolean
     */
    public function isScheduledForInsert(document)
    {
        return isset this->documentInsertions[spl_object_hash(document)];
    }

    /**
     * Checks whether a document is scheduled for upsert.
     *
     * @param object document
     * @return boolean
     */
    public function isScheduledForUpsert(document)
    {
        return isset this->documentUpserts[spl_object_hash(document)];
    }

    /**
     * Schedules a document for being updated.
     *
     * @param object document The document to schedule for being updated.
     * @throws \InvalidArgumentException
     */
    public function scheduleForUpdate(document)
    {
        var oid;

        let oid = spl_object_hash(document);
        if  ! isset this->documentIdentifiers[oid] {
            throw new \InvalidArgumentException("Document has no identity.");
        }
        if isset this->documentDeletions[oid] {
            throw new \InvalidArgumentException("Document is removed.");
        }

        if  ! isset this->documentUpdates[oid] && ! isset this->documentInsertions[oid] && ! isset this->documentUpserts[oid] {
            let this->documentUpdates[oid] = document;
        }
    }

    /**
     * INTERNAL:
     * Schedules an extra update that will be executed immediately after the
     * regular document updates within the currently running commit cycle.
     *
     * Extra updates for documents are stored as (document, changeset) tuples.
     *
     * @ignore
     * @param object document The document for which to schedule an extra update.
     * @param array changeset The changeset of the document (what to update).
     */
    public function scheduleExtraUpdate(document, changeset)
    {
        var oid, ignored, changeset2, list;

        let oid = spl_object_hash(document);
        if isset this->extraUpdates[oid] {
            let list = this->extraUpdates[oid];
            let ignored = list[0];
            let changeset2 = list[1];
            let this->extraUpdates[oid] = [document, (changeset + changeset2)];
        } else {
            let this->extraUpdates[oid] = [document, changeset];
        }
    }

    /**
     * Checks whether a document is registered as dirty in the unit of work.
     * Note: Is not very useful currently as dirty documents are only registered
     * at commit time.
     *
     * @param object document
     * @return boolean
     */
    public function isScheduledForUpdate(document)
    {
        return isset this->documentUpdates[spl_object_hash(document)];
    }

    public function isScheduledForDirtyCheck(document)
    {
        var class1;
        let class1 = this->dm->getClassMetadata(get_class(document));
        return isset this->scheduledForDirtyCheck[class1->name][spl_object_hash(document)];
    }

    /**
     * INTERNAL:
     * Schedules a document for deletion.
     *
     * @param object document
     */
    public function scheduleForDelete(document)
    {
        var oid;
        let oid = spl_object_hash(document);

        if isset this->documentInsertions[oid] {
            if this->isInIdentityMap(document) {
                this->removeFromIdentityMap(document);
            }
            unset(this->documentInsertions[oid]);
            return; // document has not been persisted yet, so nothing more to do.
        }

        if  ! this->isInIdentityMap(document) {
            return; // ignore
        }

        this->removeFromIdentityMap(document);
        let this->documentStates[oid] = self::STATE_REMOVED;

        if isset this->documentUpdates[oid] {
            unset(this->documentUpdates[oid]);
        }
        if  ! isset this->documentDeletions[oid] {
            let this->documentDeletions[oid] = document;
        }
    }

    /**
     * Checks whether a document is registered as removed/deleted with the unit
     * of work.
     *
     * @param object document
     * @return boolean
     */
    public function isScheduledForDelete(document)
    {
        return isset this->documentDeletions[spl_object_hash(document)];
    }

    /**
     * Checks whether a document is scheduled for insertion, update or deletion.
     *
     * @param document
     * @return boolean
     */
    public function isDocumentScheduled(document)
    {
        var oid;
        let oid = spl_object_hash(document);
        return isset this->documentInsertions[oid] ||
            isset this->documentUpserts[oid] ||
            isset this->documentUpdates[oid] ||
            isset this->documentDeletions[oid];
    }

    /**
     * INTERNAL:
     * Registers a document in the identity map.
     *
     * Note that documents in a hierarchy are registered with the class1name of
     * the root document. Identifiers are serialized before being used as array
     * keys to allow differentiation of equal, but not identical, values.
     *
     * @ignore
     * @param object document  The document to register.
     * @return boolean  TRUE if the registration was successful, FALSE if the identity of
     *                  the document in question is already managed.
     */
    public function addToIdentityMap(document)
    {
        var class1, id;
        let class1 = this->dm->getClassMetadata(get_class(document));

        if  ! class1->identifier {
            let id = spl_object_hash(document);
        } else {
            let id = this->documentIdentifiers[spl_object_hash(document)];
            let id = serialize(class1->getDatabaseIdentifierValue(id));
        }

        if isset this->identityMap[class1->name][id] {
            return false;
        }

        let this->identityMap[class1->name][id] = document;

        if (document instanceof NotifyPropertyChanged) {
            document->addPropertyChangedListener(this);
        }

        return true;
    }

    /**
     * Gets the state of a document with regard to the current unit of work.
     *
     * @param object   document
     * @param int|null assume The state to assume if the state is not yet known (not MANAGED or REMOVED).
     *                         This parameter can be set to improve performance of document state detection
     *                         by potentially avoiding a database lookup if the distinction between NEW and DETACHED
     *                         is either known or does not matter for the caller of the method.
     * @return int The document state.
     */
    public function getDocumentState(document, assume = null)
    {
        var oid, class1, id;

        let oid = spl_object_hash(document);

        if isset this->documentStates[oid] {
            return this->documentStates[oid];
        }

        let class1 = this->dm->getClassMetadata(get_class(document));

        if class1->isEmbeddedDocument {
            return self::STATE_NEW;
        }

        if assume !== null {
            return assume;
        }

        /* State can only be NEW or DETACHED, because MANAGED/REMOVED states are
         * known. Note that you cannot remember the NEW or DETACHED state in
         * _documentStates since the UoW does not hold references to such
         * objects and the object hash can be reused. More generally, because
         * the state may "change" between NEW/DETACHED without the UoW being
         * aware of it.
         */
        let id = class1->getIdentifierObject(document);

        if id === null {
            return self::STATE_NEW;
        }

        // Check for a version field, if available, to avoid a DB lookup.
        if class1->isVersioned {
            return (class1->getFieldValue(document, class1->versionField))
                ? self::STATE_DETACHED
                : self::STATE_NEW;
        }

        // Last try before DB lookup: check the identity map.
        if this->tryGetById(id, class1) {
            return self::STATE_DETACHED;
        }

        // DB lookup
        if this->getDocumentPersister(class1->name)->exists(document) {
            return self::STATE_DETACHED;
        }

        return self::STATE_NEW;
    }

    /**
     * INTERNAL:
     * Removes a document from the identity map. This effectively detaches the
     * document from the persistence management of Doctrine.
     *
     * @ignore
     * @param object document
     * @throws \InvalidArgumentException
     * @return boolean
     */
    public function removeFromIdentityMap(document)
    {
        var oid, class1, id;

        let oid = spl_object_hash(document);

        // Check if id is registered first
        if  ! isset this->documentIdentifiers[oid] {
            return false;
        }

        let class1 = this->dm->getClassMetadata(get_class(document));

        if  ! class1->identifier {
            let id = spl_object_hash(document);
        } else {
            let id = this->documentIdentifiers[spl_object_hash(document)];
            let id = serialize(class1->getDatabaseIdentifierValue(id));
        }

        if isset this->identityMap[class1->name][id] {
            unset(this->identityMap[class1->name][id]);
            let this->documentStates[oid] = self::STATE_DETACHED;
            return true;
        }

        return false;
    }

    /**
     * INTERNAL:
     * Gets a document in the identity map by its identifier hash.
     *
     * @ignore
     * @param mixed         id    Document identifier
     * @param ClassMetadata class1Document class
     * @return object
     * @throws InvalidArgumentException if the class1does not have an identifier
     */
    public function getById(id,  class1)
    {
        var serializedId;
        if  ! class1->identifier {
            throw new \InvalidArgumentException(sprintf("Class '%s' does not have an identifier", class1->name));
        }

        let serializedId = serialize(class1->getDatabaseIdentifierValue(id));

        return this->identityMap[class1->name][serializedId];
    }

    /**
     * INTERNAL:
     * Tries to get a document by its identifier hash. If no document is found
     * for the given hash, FALSE is returned.
     *
     * @ignore
     * @param mixed         id    Document identifier
     * @param ClassMetadata class1Document class
     * @return mixed The found document or FALSE.
     * @throws InvalidArgumentException if the class1does not have an identifier
     */
    public function tryGetById(id, class1)
    {
        var serializedId;
        if  ! class1->identifier {
            throw new \InvalidArgumentException(sprintf("Class '%s' does not have an identifier", class1->name));
        }

        let serializedId = serialize(class1->getDatabaseIdentifierValue(id));

        return isset this->identityMap[class1->name][serializedId] ?
            this->identityMap[class1->name][serializedId] : false;
    }

    /**
     * Schedules a document for dirty-checking at commit-time.
     *
     * @param object document The document to schedule for dirty-checking.
     * @todo Rename: scheduleForSynchronization
     */
    public function scheduleForDirtyCheck(document)
    {
        var class1;
        let class1 = this->dm->getClassMetadata(get_class(document));
        let this->scheduledForDirtyCheck[class1->name][spl_object_hash(document)] = document;
    }

    /**
     * Checks whether a document is registered in the identity map.
     *
     * @param object document
     * @return boolean
     */
    public function isInIdentityMap(document)
    {
        var oid, class1, id;

        let oid = spl_object_hash(document);

        if  ! isset this->documentIdentifiers[oid] {
            return false;
        }

        let class1 = this->dm->getClassMetadata(get_class(document));

        if  ! class1->identifier {
            let id = spl_object_hash(document);
        } else {
            let id = this->documentIdentifiers[spl_object_hash(document)];
            let id = serialize(class1->getDatabaseIdentifierValue(id));
        }

        return isset this->identityMap[class1->name][id];
    }

    /**
     * INTERNAL:
     * Checks whether an identifier exists in the identity map.
     *
     * @ignore
     * @param string id
     * @param string rootClassName
     * @return boolean
     */
    public function containsId(id, rootClassName)
    {
        return isset this->identityMap[rootClassName][serialize(id)];
    }

    /**
     * Persists a document as part of the current unit of work.
     *
     * @param object document The document to persist.
     */
    public function persist(document)
    {
        var class1;
        let class1 = this->dm->getClassMetadata(get_class(document));
        if class1->isMappedSuperclass {
            throw MongoDBException::cannotPersistMappedSuperclass(class1->name);
        }
        this->doPersist(document, []);
    }

    /**
     * Saves a document as part of the current unit of work.
     * This method is internally called during save() cascades as it tracks
     * the already visited documents to prevent infinite recursions.
     *
     * NOTE: This method always considers documents that are not yet known to
     * this UnitOfWork as NEW.
     *
     * @param object document The document to persist.
     * @param array visited The already visited documents.
     * @throws \InvalidArgumentException
     * @throws MongoDBException
     */
    private function doPersist(document, array visited)
    {
        var oid, class1, documentState;

        let oid = spl_object_hash(document);
        if isset visited[oid] {
            return; // Prevent infinite recursion
        }

        let visited[oid] = document; // Mark visited

        let class1 = this->dm->getClassMetadata(get_class(document));

        let documentState = this->getDocumentState(document, self::STATE_NEW);
        switch documentState {
            case self::STATE_MANAGED:
                // Nothing to do, except if policy is "deferred explicit"
                if class1->isChangeTrackingDeferredExplicit() {
                    this->scheduleForDirtyCheck(document);
                }
                break;
            case self::STATE_NEW:
                this->persistNew(class1, document);
                break;
            case self::STATE_DETACHED:
                throw new \InvalidArgumentException(
                    "Behavior of persist() for a detached document is not yet defined.");
                break;
            case self::STATE_REMOVED:
                if  ! class1->isEmbeddedDocument {
                    // Document becomes managed again
                    if this->isScheduledForDelete(document) {
                        unset(this->documentDeletions[oid]);
                    } else {
                        //FIXME: There"s more to think of here...
                        this->scheduleForInsert(class1, document);
                    }
                    break;
                }
            default:
                throw MongoDBException::invalidDocumentState(documentState);
        }

        this->cascadePersist(document, visited);
    }

    /**
     * Deletes a document as part of the current unit of work.
     *
     * @param object document The document to remove.
     */
    public function remove(document)
    {
        this->doRemove(document, []);
    }

    /**
     * Deletes a document as part of the current unit of work.
     *
     * This method is internally called during delete() cascades as it tracks
     * the already visited documents to prevent infinite recursions.
     *
     * @param object document The document to delete.
     * @param array visited The map of the already visited documents.
     * @throws MongoDBException
     */
    private function doRemove(document, array visited)
    {
        var oid, class1, documentState;

        let oid = spl_object_hash(document);
        if isset visited[oid] {
            return; // Prevent infinite recursion
        }

        let visited[oid] = document; // mark visited

        /* Cascade first, because scheduleForDelete() removes the entity from
         * the identity map, which can cause problems when a lazy Proxy has to
         * be initialized for the cascade operation.
         */
        this->cascadeRemove(document, visited);

        let class1 = this->dm->getClassMetadata(get_class(document));
        let documentState = this->getDocumentState(document);
        switch documentState {
            case self::STATE_NEW:
            case self::STATE_REMOVED:
                // nothing to do
                break;
            case self::STATE_MANAGED:
                if  ! empty class1->lifecycleCallbacks[Events::PREREMOVE] {
                    class1->invokeLifecycleCallbacks(Events::PREREMOVE, document);
                }
                if this->evm->hasListeners(Events::PREREMOVE) {
                    this->evm->dispatchEvent(Events::PREREMOVE, new LifecycleEventArgs(document, this->dm));
                }
                this->scheduleForDelete(document);
                this->cascadePreRemove(class1, document);
                break;
            case self::STATE_DETACHED:
                throw MongoDBException::detachedDocumentCannotBeRemoved();
            default:
                throw MongoDBException::invalidDocumentState(documentState);
        }
    }

    /**
     * Cascades the preRemove event to embedded documents.
     *
     * @param ClassMetadata class
     * @param object document
     */
    private function cascadePreRemove(class1, document)
    {
        var hasPreRemoveListeners, mapping, value, entry, entryClass;

        let hasPreRemoveListeners = this->evm->hasListeners(Events::PREREMOVE);

        for mapping in class1->fieldMappings {
            if isset mapping["embedded"] {
                let value = class1->reflFields[mapping["fieldName"]]->getValue(document);
                if value === null {
                    continue;
                }
                if mapping["type"] === "one" {
                    let value = [value];
                }
                for entry in value {
                    let entryClass = this->dm->getClassMetadata(get_class(entry));
                    if  ! empty entryClass->lifecycleCallbacks[Events::PREREMOVE] {
                        entryClass->invokeLifecycleCallbacks(Events::PREREMOVE, entry);
                    }
                    if hasPreRemoveListeners {
                        this->evm->dispatchEvent(Events::PREREMOVE, new LifecycleEventArgs(entry, this->dm));
                    }
                    this->cascadePreRemove(entryClass, entry);
                }
            }
        }
    }

    /**
     * Cascades the postRemove event to embedded documents.
     *
     * @param ClassMetadata class
     * @param object document
     */
    private function cascadePostRemove(class1, document)
    {
        var hasPostRemoveListeners, mapping, value, entry, entryClass;

        let hasPostRemoveListeners = this->evm->hasListeners(Events::POSTREMOVE);

        for mapping in class1->fieldMappings {
            if isset mapping["embedded"] {
                let value = class1->reflFields[mapping["fieldName"]]->getValue(document);
                if value === null {
                    continue;
                }
                if mapping["type"] === "one" {
                    let value = [value];
                }
                for entry in value {
                    let entryClass = this->dm->getClassMetadata(get_class(entry));
                    if  ! empty entryClass->lifecycleCallbacks[Events::POSTREMOVE] {
                        entryClass->invokeLifecycleCallbacks(Events::POSTREMOVE, entry);
                    }
                    if hasPostRemoveListeners {
                        this->evm->dispatchEvent(Events::POSTREMOVE, new LifecycleEventArgs(entry, this->dm));
                    }
                    this->cascadePostRemove(entryClass, entry);
                }
            }
        }
    }

    /**
     * Merges the state of the given detached document into this UnitOfWork.
     *
     * @param object document
     * @return object The managed copy of the document.
     */
    public function merge(document)
    {
        return this->doMerge(document, []);
    }

    /**
     * Executes a merge operation on a document.
     *
     * @param object      document
     * @param array       visited
     * @param object|null prevManagedCopy
     * @param array|null  assoc
     *
     * @return object The managed copy of the document.
     *
     * @throws InvalidArgumentException If the document instance is NEW.
     * @throws LockException If the entity uses optimistic locking through a
     *                       version attribute and the version check against the
     *                       managed copy fails.
     */
    private function doMerge(document, array visited, prevManagedCopy = null, assoc = null)
    {
        var oid, class1, managedCopy, id, prop, managedCopyVersion, documentVersion, name,
            assoc2, other, targetDocument, targetClass, relatedId, a, mergeCol, managedCol, 
            assocField, prevClass;

        let oid = spl_object_hash(document);

        if isset visited[oid] {
            return visited[oid]; // Prevent infinite recursion
        }

        let visited[oid] = document; // mark visited

        let class1 = this->dm->getClassMetadata(get_class(document));

        /* First we assume DETACHED, although it can still be NEW but we can
         * avoid an extra DB round trip this way. If it is not MANAGED but has
         * an identity, we need to fetch it from the DB anyway in order to
         * merge. MANAGED documents are ignored by the merge operation.
         */
        let managedCopy = document;

        if this->getDocumentState(document, self::STATE_DETACHED) !== self::STATE_MANAGED {
            if (document instanceof Proxy) && ! document->__isInitialized() {
                document->__load();
            }

            // Try to look the document up in the identity map.
            let id = class1->isEmbeddedDocument ? null : class1->getIdentifierObject(document);

            if id === null {
                // If there is no identifier, it is actually NEW.
                let managedCopy = class1->newInstance();
                this->persistNew(class1, managedCopy);
            } else {
                let managedCopy = this->tryGetById(id, class1);

                if managedCopy {
                    // We have the document in memory already, just make sure it is not removed.
                    if this->getDocumentState(managedCopy) === self::STATE_REMOVED {
                        throw new \InvalidArgumentException("Removed entity detected during merge. Cannot merge with a removed entity.");
                    }
                } else {
                    // We need to fetch the managed copy in order to merge.
                    let managedCopy = this->dm->find(class1->name, id);
                }

                if managedCopy === null {
                    // If the identifier is ASSIGNED, it is NEW
                    let managedCopy = class1->newInstance();
                    class1->setIdentifierValue(managedCopy, id);
                    this->persistNew(class1, managedCopy);
                } else {
                    if (managedCopy instanceof Proxy) && ! managedCopy->__isInitialized__ {
                        managedCopy->__load();
                    }
                }
            }

            if class1->isVersioned {
                let managedCopyVersion = class1->reflFields[class1->versionField]->getValue(managedCopy);
                let documentVersion = class1->reflFields[class1->versionField]->getValue(document);

                // Throw exception if versions don"t match
                if managedCopyVersion != documentVersion {
                    throw LockException::lockFailedVersionMissmatch(document, documentVersion, managedCopyVersion);
                }
            }

            // Merge state of document into existing (managed) document
            for prop in class1->reflClass->getProperties() {
                let name = prop->name;
                prop->setAccessible(true);
                if  ! isset class1->associationMappings[name] {
                    if  ! class1->isIdentifier(name) {
                        prop->setValue(managedCopy, prop->getValue(document));
                    }
                } else {
                    let assoc2 = class1->associationMappings[name];

                    if assoc2["type"] === "one" {
                        let other = prop->getValue(document);

                        if other === null {
                            prop->setValue(managedCopy, null);
                        } else {
                            if (other instanceof Proxy) && ! other->__isInitialized__ {
                                // Do not merge fields marked lazy that have not been fetched
                                continue;
                            } else {
                                if  ! assoc2["isCascadeMerge"] {
                                    if this->getDocumentState(other) === self::STATE_DETACHED {
                                        let targetDocument = isset assoc2["targetDocument"] ? assoc2["targetDocument"] : get_class(other);
                                        /* @var targetClass \Doctrine\ODM\MongoDB\Mapping\ClassMetadataInfo */
                                        let targetClass = this->dm->getClassMetadata(targetDocument);
                                        let relatedId = targetClass->getIdentifierObject(other);

                                        if targetClass->subClasses {
                                            let other = this->dm->find(targetClass->name, relatedId);
                                        } else {
                                            let a = targetClass->identifier;
                                            let other = this->dm->getProxyFactory()->getProxy(assoc2["targetDocument"], [a: relatedId]);
                                            this->registerManaged(other, relatedId, []);
                                        }
                                    }

                                    prop->setValue(managedCopy, other);
                                }
                            }
                        }
                    } else {
                        let mergeCol = prop->getValue(document);

                        if (mergeCol instanceof PersistentCollection) && ! mergeCol->isInitialized() {
                            /* Do not merge fields marked lazy that have not
                             * been fetched. Keep the lazy persistent collection
                             * of the managed copy.
                             */
                            continue;
                        }

                        let managedCol = prop->getValue(managedCopy);

                        if  ! managedCol {
                            let managedCol = new PersistentCollection(new ArrayCollection(), this->dm, this);
                            managedCol->setOwner(managedCopy, assoc2);
                            prop->setValue(managedCopy, managedCol);
                            let this->originalDocumentData[oid][name] = managedCol;
                        }

                        /* Note: do not process association"s target documents.
                         * They will be handled during the cascade. Initialize
                         * and, if necessary, clear managedCol for now.
                         */
                        if assoc2["isCascadeMerge"] {
                            managedCol->initialize();

                            // If managedCol differs from the merged collection, clear and set dirty
                            if  ! managedCol->isEmpty() && managedCol !== mergeCol {
                                managedCol->unwrap()->clear();
                                managedCol->setDirty(true);

                                if assoc2["isOwningSide"] && class1->isChangeTrackingNotify() {
                                    this->scheduleForDirtyCheck(managedCopy);
                                }
                            }
                        }
                    }
                }

                if class1->isChangeTrackingNotify() {
                    // Just treat all properties as changed, there is no other choice.
                    this->propertyChanged(managedCopy, name, null, prop->getValue(managedCopy));
                }
            }

            if class1->isChangeTrackingDeferredExplicit() {
                this->scheduleForDirtyCheck(document);
            }
        }

        if prevManagedCopy !== null {
            let assocField = assoc["fieldName"];
            let prevClass = this->dm->getClassMetadata(get_class(prevManagedCopy));

            if assoc["type"] === "one" {
                prevClass->reflFields[assocField]->setValue(prevManagedCopy, managedCopy);
            } else {
                prevClass->reflFields[assocField]->getValue(prevManagedCopy)->add(managedCopy);

                if assoc["type"] === "many" && isset assoc["mappedBy"] {
                    class1->reflFields[assoc["mappedBy"]]->setValue(managedCopy, prevManagedCopy);
                }
            }
        }

        // Mark the managed copy visited as well
        let visited[spl_object_hash(managedCopy)] = true;

        this->cascadeMerge(document, managedCopy, visited);

        return managedCopy;
    }

    /**
     * Detaches a document from the persistence management. It"s persistence will
     * no longer be managed by Doctrine.
     *
     * @param object document The document to detach.
     */
    public function detach(document)
    {
        this->doDetach(document, []);
    }

    /**
     * Executes a detach operation on the given document.
     *
     * @param object document
     * @param array visited
     * @internal This method always considers documents with an assigned identifier as DETACHED.
     */
    private function doDetach(document, array visited)
    {
        var oid;

        let oid = spl_object_hash(document);
        if isset visited[oid] {
            return; // Prevent infinite recursion
        }

        let visited[oid] = document; // mark visited

        switch this->getDocumentState(document, self::STATE_DETACHED) {
            case self::STATE_MANAGED:
                this->removeFromIdentityMap(document);
                unset(this->documentInsertions[oid]);
                unset(this->documentUpdates[oid]);
                unset(this->documentDeletions[oid]);
                unset(this->documentIdentifiers[oid]);
                unset(this->documentStates[oid]);
                unset(this->originalDocumentData[oid]);
                unset(this->parentAssociations[oid]);
                unset(this->documentUpserts[oid]);
                break;
            case self::STATE_NEW:
            case self::STATE_DETACHED:
                return;
        }

        this->cascadeDetach(document, visited);
    }

    /**
     * Refreshes the state of the given document from the database, overwriting
     * any local, unpersisted changes.
     *
     * @param object document The document to refresh.
     * @throws \InvalidArgumentException If the document is not MANAGED.
     */
    public function refresh(document)
    {
        this->doRefresh(document, []);
    }

    /**
     * Executes a refresh operation on a document.
     *
     * @param object document The document to refresh.
     * @param array visited The already visited documents during cascades.
     * @throws \InvalidArgumentException If the document is not MANAGED.
     */
    private function doRefresh(document, array visited)
    {
        var oid, id, class1;

        let oid = spl_object_hash(document);
        if isset visited[oid] {
            return; // Prevent infinite recursion
        }

        let visited[oid] = document; // mark visited

        let class1 = this->dm->getClassMetadata(get_class(document));
        if this->getDocumentState(document) == self::STATE_MANAGED {
            let id = class1->getDatabaseIdentifierValue(this->documentIdentifiers[oid]);
            this->getDocumentPersister(class1->name)->refresh(id, document);
        } else {
            throw new \InvalidArgumentException("Document is not MANAGED.");
        }

        this->cascadeRefresh(document, visited);
    }

    /**
     * Cascades a refresh operation to associated documents.
     *
     * @param object document
     * @param array visited
     */
    private function cascadeRefresh(document, array visited)
    {
        var class1, mapping, relatedDocuments, relatedDocument;

        let class1 = this->dm->getClassMetadata(get_class(document));
        for mapping in class1->fieldMappings {
            if  ! mapping["isCascadeRefresh"] {
                continue;
            }
            if isset mapping["embedded"] {
                let relatedDocuments = class1->reflFields[mapping["fieldName"]]->getValue(document);
                if ((relatedDocuments instanceof Collection) || is_array(relatedDocuments)) {
                    if (relatedDocuments instanceof PersistentCollection) {
                        // Unwrap so that foreach() does not initialize
                        let relatedDocuments = relatedDocuments->unwrap();
                    }
                    for relatedDocument in relatedDocuments {
                        this->cascadeRefresh(relatedDocument, visited);
                    }
                } else {
                    if relatedDocuments !== null {
                        this->cascadeRefresh(relatedDocuments, visited);
                    }
                }
            } else {
                if isset mapping["reference"] {
                    let relatedDocuments = class1->reflFields[mapping["fieldName"]]->getValue(document);
                    if ((relatedDocuments instanceof Collection) || is_array(relatedDocuments)) {
                        if (relatedDocuments instanceof PersistentCollection) {
                            // Unwrap so that foreach() does not initialize
                            let relatedDocuments = relatedDocuments->unwrap();
                        }
                        for relatedDocument in relatedDocuments {
                            this->doRefresh(relatedDocument, visited);
                        }
                    } else {
                        if relatedDocuments !== null {
                            this->doRefresh(relatedDocuments, visited);
                        }
                    }
                }
            }
        }
    }

    /**
     * Cascades a detach operation to associated documents.
     *
     * @param object document
     * @param array visited
     */
    private function cascadeDetach(document, array visited)
    {
        var class1, mapping, relatedDocuments, relatedDocument;

        let class1= this->dm->getClassMetadata(get_class(document));
        for mapping in class1->fieldMappings {
            if  ! mapping["isCascadeDetach"] {
                continue;
            }
            if isset mapping["embedded"] {
                let relatedDocuments = class1->reflFields[mapping["fieldName"]]->getValue(document);
                if ((relatedDocuments instanceof Collection) || is_array(relatedDocuments)) {
                    if (relatedDocuments instanceof PersistentCollection) {
                        // Unwrap so that foreach() does not initialize
                        let relatedDocuments = relatedDocuments->unwrap();
                    }
                    for relatedDocument in relatedDocuments {
                        this->cascadeDetach(relatedDocument, visited);
                    }
                } else {
                    if relatedDocuments !== null {
                        this->cascadeDetach(relatedDocuments, visited);
                    }
                }
            } else {
                if isset mapping["reference"] {
                    let relatedDocuments = class1->reflFields[mapping["fieldName"]]->getValue(document);
                    if ((relatedDocuments instanceof Collection) || is_array(relatedDocuments)) {
                        if (relatedDocuments instanceof PersistentCollection) {
                            // Unwrap so that foreach() does not initialize
                            let relatedDocuments = relatedDocuments->unwrap();
                        }
                        for relatedDocument in relatedDocuments {
                            this->doDetach(relatedDocument, visited);
                        }
                    } else {
                        if relatedDocuments !== null {
                            this->doDetach(relatedDocuments, visited);
                        }
                    }
                }
            }
        }
    }

    public function fun_anon1(assoc) 
    { 
        return assoc["isCascadeMerge"]; 
    }

    /**
     * Cascades a merge operation to associated documents.
     *
     * @param object document
     * @param object managedCopy
     * @param array visited
     */
    private function cascadeMerge(document, managedCopy, array visited)
    {
        var class1, associationMappings = [], relatedDocument, relatedDocuments, assoc;

        let class1 = this->dm->getClassMetadata(get_class(document));

        /*
        ?????
        let associationMappings = array_filter(
            class1->associationMappings,
            fun_anon1(assoc)
        );*/

        for assoc in associationMappings {
            let relatedDocuments = class1->reflFields[assoc["fieldName"]]->getValue(document);

            if (relatedDocuments instanceof Collection) || is_array(relatedDocuments) {
                if relatedDocuments === class1->reflFields[assoc["fieldName"]]->getValue(managedCopy) {
                    // Collections are the same, so there is nothing to do
                    continue;
                }

                if (relatedDocuments instanceof PersistentCollection) {
                    // Unwrap so that foreach() does not initialize
                    let relatedDocuments = relatedDocuments->unwrap();
                }

                for relatedDocument in relatedDocuments {
                    this->doMerge(relatedDocument, visited, managedCopy, assoc);
                }
            } else {
                if relatedDocuments !== null {
                    this->doMerge(relatedDocuments, visited, managedCopy, assoc);
                }
            }
        }
    }

    /**
     * Cascades the save operation to associated documents.
     *
     * @param object document
     * @param array visited
     * @param array insertNow
     */
    private function cascadePersist(document, array visited)
    {
        var class1, fieldName, mapping, relatedDocuments, relatedDocument;

        let class1= this->dm->getClassMetadata(get_class(document));

        for fieldName, mapping in class1->associationMappings {
            if  ! mapping["isCascadePersist"] {
                continue;
            }

            let relatedDocuments = class1->reflFields[fieldName]->getValue(document);

            if (relatedDocuments instanceof Collection) || is_array(relatedDocuments) {
                if (relatedDocuments instanceof PersistentCollection) {
                    // Unwrap so that foreach() does not initialize
                    let relatedDocuments = relatedDocuments->unwrap();
                }

                for relatedDocument in relatedDocuments {
                    this->doPersist(relatedDocument, visited);
                }
            } else {
                if relatedDocuments !== null {
                    this->doPersist(relatedDocuments, visited);
                }
            }
        }
    }

    /**
     * Cascades the delete operation to associated documents.
     *
     * @param object document
     * @param array visited
     */
    private function cascadeRemove(document, array visited)
    {
        var class1, mapping, relatedDocument, relatedDocuments;

        let class1 = this->dm->getClassMetadata(get_class(document));
        for mapping in class1->fieldMappings {
            if  ! mapping["isCascadeRemove"] {
                continue;
            }
            if (document instanceof Proxy) && ! document->__isInitialized__ {
                document->__load();
            }
            if isset mapping["embedded"] {
                let relatedDocuments = class1->reflFields[mapping["fieldName"]]->getValue(document);
                if ((relatedDocuments instanceof Collection) || is_array(relatedDocuments)) {
                    // If its a PersistentCollection initialization is intended! No unwrap!
                    for relatedDocument in relatedDocuments {
                        this->cascadeRemove(relatedDocument, visited);
                    }
                } else {
                    if relatedDocuments !== null {
                        this->cascadeRemove(relatedDocuments, visited);
                    }
                }
            } else {
                if isset mapping["reference"] {
                    let relatedDocuments = class1->reflFields[mapping["fieldName"]]->getValue(document);
                    if ((relatedDocuments instanceof Collection) || is_array(relatedDocuments)) {
                        // If its a PersistentCollection initialization is intended! No unwrap!
                        for relatedDocument in relatedDocuments {
                            this->doRemove(relatedDocument, visited);
                        }
                    } else {
                        if relatedDocuments !== null {
                            this->doRemove(relatedDocuments, visited);
                        }
                    }
                }
            }
        }
    }

    /**
     * Acquire a lock on the given document.
     *
     * @param object document
     * @param int lockMode
     * @param int lockVersion
     * @throws LockException
     * @throws \InvalidArgumentException
     */
    public function lock(document, lockMode, lockVersion = null)
    {
        var documentName, class1, documentVersion;

        if this->getDocumentState(document) != self::STATE_MANAGED {
            throw new \InvalidArgumentException("Document is not MANAGED.");
        }

        let documentName = get_class(document);
        let class1 = this->dm->getClassMetadata(documentName);

        if lockMode == LockMode::OPTIMISTIC {
            if  ! class1->isVersioned {
                throw LockException::notVersioned(documentName);
            }

            if lockVersion != null {
                let documentVersion = class1->reflFields[class1->versionField]->getValue(document);
                if documentVersion != lockVersion {
                    throw LockException::lockFailedVersionMissmatch(document, lockVersion, documentVersion);
                }
            }
        } else {
            if in_array(lockMode, [LockMode::PESSIMISTIC_READ, LockMode::PESSIMISTIC_WRITE]) {
                this->getDocumentPersister(class1->name)->lock(document, lockMode);
            }
        }
    }

    /**
     * Releases a lock on the given document.
     *
     * @param object document
     * @throws \InvalidArgumentException
     */
    public function unlock(document)
    {
        var documentName;

        if this->getDocumentState(document) != self::STATE_MANAGED {
            throw new \InvalidArgumentException("Document is not MANAGED.");
        }
        let documentName = get_class(document);
        this->getDocumentPersister(documentName)->unlock(document);
    }

    /**
     * Gets the CommitOrderCalculator used by the UnitOfWork to order commits.
     *
     * @return \Doctrine\ODM\MongoDB\Internal\CommitOrderCalculator
     */
    public function getCommitOrderCalculator()
    {
        if this->commitOrderCalculator === null {
            let this->commitOrderCalculator = new CommitOrderCalculator;
        }
        return this->commitOrderCalculator;
    }

    /**
     * Clears the UnitOfWork.
     *
     * @param string|null documentName if given, only documents of this type will get detached.
     */
    public function clear(documentName = null)
    {

        var className, documents, document;

        if documentName === null {
            let this->identityMap = "";
            let this->documentIdentifiers = "";
            let this->originalDocumentData = "";
            let this->documentChangeSets = "";
            let this->documentStates = "";
            let this->scheduledForDirtyCheck = "";
            let this->documentInsertions = "";
            let this->documentUpserts = "";
            let this->documentUpdates = "";
            let this->documentDeletions = "";
            let this->extraUpdates = "";
            let this->collectionUpdates = "";
            let this->collectionDeletions = "";
            let this->parentAssociations = "";
            let this->orphanRemovals = [];

            if this->commitOrderCalculator !== null {
                this->commitOrderCalculator->clear();
            }
        } else {
            for className, documents in this->identityMap {
                if className === documentName {
                    for document in documents {
                        this->doDetach(document, [], true);
                    }
                }
            }
        }

        if this->evm->hasListeners(Events::ONCLEAR) {
            this->evm->dispatchEvent(Events::ONCLEAR, new Event\OnClearEventArgs(this->dm, documentName));
        }
    }

    /**
     * INTERNAL:
     * Schedules an embedded document for removal. The remove() operation will be
     * invoked on that document at the beginning of the next commit of this
     * UnitOfWork.
     *
     * @ignore
     * @param object document
     */
    public function scheduleOrphanRemoval(document)
    {
        let this->orphanRemovals[spl_object_hash(document)] = document;
    }

    /**
     * INTERNAL:
     * Schedules a complete collection for removal when this UnitOfWork commits.
     *
     * @param PersistentCollection coll
     */
    public function scheduleCollectionDeletion( coll)
    {
        //TODO: if coll is already scheduled for recreation ... what to do?
        // Just remove coll from the scheduled recreations?
        let this->collectionDeletions[] = coll;
    }

    /**
     * Checks whether a PersistentCollection is scheduled for deletion.
     *
     * @param PersistentCollection coll
     * @return boolean
     */
    public function isCollectionScheduledForDeletion( coll)
    {
        return in_array(coll, this->collectionDeletions, true);
    }

    /**
     * Checks whether a PersistentCollection is scheduled for update.
     *
     * @param PersistentCollection coll
     * @return boolean
     */
    public function isCollectionScheduledForUpdate( coll)
    {
        return in_array(coll, this->collectionUpdates, true);
    }

    /**
     * Gets the class1name for an association (embed or reference) with respect
     * to any discriminator value.
     *
     * @param array mapping Field mapping for the association
     * @param array data    Data for the embedded document or reference
     */
    public function getClassNameForAssociation(array mapping, array data)
    {
        var discriminatorField, discriminatorValue, class1;

        let discriminatorField = isset mapping["discriminatorField"] ? mapping["discriminatorField"] : null;

        if discriminatorField && isset data[discriminatorField] {
            let discriminatorValue = data[discriminatorField];

            return isset mapping["discriminatorMap"][discriminatorValue]
                ? mapping["discriminatorMap"][discriminatorValue]
                : discriminatorValue;
        }

        let class1 = this->dm->getClassMetadata(mapping["targetDocument"]);

        if class1->discriminatorField && isset data[class1->discriminatorField] {
            let discriminatorValue = data[class1->discriminatorField];

            return isset class1->discriminatorMap[discriminatorValue]
                ? class1->discriminatorMap[discriminatorValue]
                : discriminatorValue;
        }

        return mapping["targetDocument"];
    }

    /**
     * INTERNAL:
     * Creates a document. Used for reconstitution of documents during hydration.
     *
     * @ignore
     * @param string className The name of the document class.
     * @param array data The data for the document.
     * @param array hints Any hints to account for during reconstitution/lookup of the document.
     * @return object The document instance.
     * @internal Highly performance-sensitive method.
     */
    public function getOrCreateDocument(className, data, hints = [])
    {
        var class1, discriminatorValue, serializedId, document, oid, overrideLocalValues, id;

        let class1 = this->dm->getClassMetadata(className);

        // @TODO figure out how to remove this
        if isset class1->discriminatorField && isset data[class1->discriminatorField] {
            let discriminatorValue = data[class1->discriminatorField];

            let className = isset class1->discriminatorMap[discriminatorValue]
                ? class1->discriminatorMap[discriminatorValue]
                : discriminatorValue;

            let class1 = this->dm->getClassMetadata(className);

            unset(data[class1->discriminatorField]);
        }

        let id = class1->getDatabaseIdentifierValue(data["_id"]);
        let serializedId = serialize(id);

        if isset this->identityMap[class1->name][serializedId] {
            let document = this->identityMap[class1->name][serializedId];
            let oid = spl_object_hash(document);
            if (document instanceof Proxy) && ! document->__isInitialized__ {
                let document->__isInitialized__ = true;
                let overrideLocalValues = true;
                if (document instanceof NotifyPropertyChanged) {
                    document->addPropertyChangedListener(this);
                }
            } else {
                let overrideLocalValues = ! empty hints[Query::HINT_REFRESH];
            }
            if overrideLocalValues {
                let data = this->hydratorFactory->hydrate(document, data, hints);
                let this->originalDocumentData[oid] = data;
            }
        } else {
            let document = class1->newInstance();
            this->registerManaged(document, id, data);
            let oid = spl_object_hash(document);
            let this->documentStates[oid] = self::STATE_MANAGED;
            let this->identityMap[class1->name][serializedId] = document;
            let data = this->hydratorFactory->hydrate(document, data, hints);
            let this->originalDocumentData[oid] = data;
        }
        return document;
    }

    /**
     * Cascades the preLoad event to embedded documents.
     *
     * @param ClassMetadata class
     * @param object document
     * @param array data
     */
    private function cascadePreLoad(class1, document, data)
    {
        var hasPreLoadListeners, mapping, value, entry, args, entryClass;

        let hasPreLoadListeners = this->evm->hasListeners(Events::PRELOAD);

        for mapping in class1->fieldMappings {
            if isset mapping["embedded"] {
                let value = class1->reflFields[mapping["fieldName"]]->getValue(document);
                if value === null {
                    continue;
                }
                if mapping["type"] === "one" {
                    let value = [value];
                }
                for entry in value {
                    let entryClass = this->dm->getClassMetadata(get_class(entry));
                    if  ! empty entryClass->lifecycleCallbacks[Events::PRELOAD] {
                        let args = [data];
                        entryClass->invokeLifecycleCallbacks(Events::PRELOAD, entry, args);
                    }
                    if hasPreLoadListeners {
                        this->evm->dispatchEvent(Events::PRELOAD, new PreLoadEventArgs(entry, this->dm, data[mapping["name"]]));
                    }
                    this->cascadePreLoad(entryClass, entry, data[mapping["name"]]);
                }
            }
        }
    }

    /**
     * Initializes (loads) an uninitialized persistent collection of a document.
     *
     * @param PersistentCollection collection The collection to initialize.
     */
    public function loadCollection( collection)
    {
        this->getDocumentPersister(get_class(collection->getOwner()))->loadCollection(collection);
    }

    /**
     * Gets the identity map of the UnitOfWork.
     *
     * @return array
     */
    public function getIdentityMap()
    {
        return this->identityMap;
    }

    /**
     * Gets the original data of a document. The original data is the data that was
     * present at the time the document was reconstituted from the database.
     *
     * @param object document
     * @return array
     */
    public function getOriginalDocumentData(document)
    {
        var oid;

        let oid = spl_object_hash(document);
        if isset this->originalDocumentData[oid] {
            return this->originalDocumentData[oid];
        }
        return [];
    }

    /**
     * @ignore
     */
    public function setOriginalDocumentData(document, array data)
    {
        let this->originalDocumentData[spl_object_hash(document)] = data;
    }

    /**
     * INTERNAL:
     * Sets a property value of the original data array of a document.
     *
     * @ignore
     * @param string oid
     * @param string property
     * @param mixed value
     */
    public function setOriginalDocumentProperty(oid, property, value)
    {
        let this->originalDocumentData[oid][property] = value;
    }

    /**
     * Gets the identifier of a document.
     *
     * @param object document
     * @return mixed The identifier value
     */
    public function getDocumentIdentifier(document)
    {
        return isset this->documentIdentifiers[spl_object_hash(document)] ?
            this->documentIdentifiers[spl_object_hash(document)] : null;
    }

    /**
     * Checks whether the UnitOfWork has any pending insertions.
     *
     * @return boolean TRUE if this UnitOfWork has pending insertions, FALSE otherwise.
     */
    public function hasPendingInsertions()
    {
        return ! empty this->documentInsertions ;
    }

    /**
     * Calculates the size of the UnitOfWork. The size of the UnitOfWork is the
     * number of documents in the identity map.
     *
     * @return integer
     */
    public function size()
    {
        var count, documentSet;

        let count = 0;
        for documentSet in this->identityMap {
            let count += count(documentSet);
        }
        return count;
    }

    /**
     * INTERNAL:
     * Registers a document as managed.
     *
     * TODO: This method assumes that id is a valid PHP identifier for the
     * document class. If the class1expects its database identifier to be a
     * MongoId, and an incompatible id is registered (e.g. an integer), the
     * document identifiers map will become inconsistent with the identity map.
     * In the future, we may want to round-trip id through a PHP and database
     * conversion and throw an exception if it"s inconsistent.
     *
     * @param object document The document.
     * @param array id The identifier values.
     * @param array data The original document data.
     */
    public function registerManaged(document, id, array data)
    {
        var oid, class1;

        let oid = spl_object_hash(document);
        let class1 = this->dm->getClassMetadata(get_class(document));

        if  ! class1->identifier || id === null {
            let this->documentIdentifiers[oid] = oid;
        } else {
            let this->documentIdentifiers[oid] = class1->getPHPIdentifierValue(id);
        }

        let this->documentStates[oid] = self::STATE_MANAGED;
        let this->originalDocumentData[oid] = data;
        this->addToIdentityMap(document);
    }

    /**
     * INTERNAL:
     * Clears the property changeset of the document with the given OID.
     *
     * @param string oid The document"s OID.
     */
    public function clearDocumentChangeSet(oid)
    {
        let this->documentChangeSets[oid] = [];
    }

    /**
     * Notifies this UnitOfWork of a property change in a document.
     *
     * @param object document The document that owns the property.
     * @param string propertyName The name of the property that changed.
     * @param mixed oldValue The old value of the property.
     * @param mixed newValue The new value of the property.
     */
    public function propertyChanged(document, propertyName, oldValue, newValue)
    {
        var oid, class1;

        let oid = spl_object_hash(document);
        let class1 = this->dm->getClassMetadata(get_class(document));

        if  ! isset class1->fieldMappings[propertyName] {
            return; // ignore non-persistent fields
        }

        // Update changeset and mark document for synchronization
        let this->documentChangeSets[oid][propertyName] = [oldValue, newValue];
        if  ! isset this->scheduledForDirtyCheck[class1->name][oid] {
            this->scheduleForDirtyCheck(document);
        }
    }

    /**
     * Gets the currently scheduled document insertions in this UnitOfWork.
     *
     * @return array
     */
    public function getScheduledDocumentInsertions()
    {
        return this->documentInsertions;
    }

    /**
     * Gets the currently scheduled document upserts in this UnitOfWork.
     *
     * @return array
     */
    public function getScheduledDocumentUpserts()
    {
        return this->documentUpserts;
    }

    /**
     * Gets the currently scheduled document updates in this UnitOfWork.
     *
     * @return array
     */
    public function getScheduledDocumentUpdates()
    {
        return this->documentUpdates;
    }

    /**
     * Gets the currently scheduled document deletions in this UnitOfWork.
     *
     * @return array
     */
    public function getScheduledDocumentDeletions()
    {
        return this->documentDeletions;
    }

    /**
     * Get the currently scheduled complete collection deletions
     *
     * @return array
     */
    public function getScheduledCollectionDeletions()
    {
        return this->collectionDeletions;
    }

    /**
     * Gets the currently scheduled collection inserts, updates and deletes.
     *
     * @return array
     */
    public function getScheduledCollectionUpdates()
    {
        return this->collectionUpdates;
    }

    /**
     * Helper method to initialize a lazy loading proxy or persistent collection.
     *
     * @param object
     * @return void
     */
    public function initializeObject(obj)
    {

        if (obj instanceof Proxy) {
            obj->__load();
        } else {
            if (obj instanceof PersistentCollection) {
                obj->initialize();
            }
        }
    }

    private static function objToStr(obj)
    {
        return method_exists(obj, "__toString") ? (string) obj : get_class(obj) . "@" . spl_object_hash(obj);
    }
}
