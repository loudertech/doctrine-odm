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

use Doctrine\ODM\MongoDB\DocumentManager;
use Doctrine\ODM\MongoDB\Mapping\ClassMetadata;
use Doctrine\ODM\MongoDB\Mapping\ClassMetadataInfo;
use Doctrine\ODM\MongoDB\PersistentCollection;
use Doctrine\ODM\MongoDB\Types\Type;
use Doctrine\ODM\MongoDB\UnitOfWork;

/**
 * PersistenceBuilder builds the queries used by the persisters to update and insert
 * documents when a DocumentManager is flushed. It uses the changeset information in the
 * UnitOfWork to build queries using atomic operators like set, unset, etc.
 *
 * @since       1.0
 * @author      Jonathan H. Wage <jonwage@gmail.com>
 */
class PersistenceBuilder
{
    /**
     * The DocumentManager instance.
     *
     * @var DocumentManager
     */
    private dm;

    /**
     * The UnitOfWork instance.
     *
     * @var UnitOfWork
     */
    private uow;

    /**
     * Initializes a new PersistenceBuilder instance.
     *
     * @param DocumentManager dm
     * @param UnitOfWork uow
     */
    public function __construct( dm,  uow)
    {
        let this->dm = dm;
        let this->uow = uow;
    }

    /**
     * Prepares the array that is ready to be inserted to mongodb for a given object document.
     *
     * @param object document
     * @return array insertData
     */
    public function prepareInsertData(document)
    {
        var class1, changeset, insertData, mapping, new_, value;

        let class1 = this->dm->getClassMetadata(get_class(document));
        let changeset = this->uow->getDocumentChangeSet(document);

        let insertData = [];
        for mapping in class1->fieldMappings {

            // @ReferenceMany and @EmbedMany are inserted later
            if mapping["type"] === ClassMetadataInfo::MANY {
                continue;
            }

            let new_ = isset changeset[mapping["fieldName"]][1] ? changeset[mapping["fieldName"]][1] : null;

            // Don"t store null values unless nullable === true
            if new_ === null && mapping["nullable"] === false {
                continue;
            }

            let value = null;
            if new_ !== null {
                // @Field, @String, @Date, etc.
                if  ! isset mapping["association"] {
                    let value = Type::getType(mapping["type"])->convertToDatabaseValue(new_);

                // @ReferenceOne
                } else {
                    if isset mapping["association"] && mapping["association"] === ClassMetadataInfo::REFERENCE_ONE {
                        if mapping["isInverseSide"] {
                            continue;
                        }

                        let value = this->prepareReferencedDocumentValue(mapping, new_);
                        

                    // @EmbedOne
                    } else {
                        if isset mapping["association"] && mapping["association"] === ClassMetadataInfo::EMBED_ONE {
                            let value = this->prepareEmbeddedDocumentValue(mapping, new_);
                        }
                    }
                }
            }

            let insertData[mapping["name"]] = value;
        }

        // add discriminator if the class has one
        if isset class1->discriminatorField {
            let insertData[class1->discriminatorField] = isset class1->discriminatorValue
                ? class1->discriminatorValue
                : class1->name;
        }

        return insertData;
    }

    /**
     * Prepares the update query to update a given document object in mongodb.
     *
     * @param object document
     * @return array updateData
     */
    public function prepareUpdateData(document)
    {
        var class1, changeset, vupdateData, fieldName, mapping, list, old, new_, change,
            updateData = [], update, cmd, values, key, value, embedded, embeddedDoc, name;

        let class1 = this->dm->getClassMetadata(get_class(document));
        let changeset = this->uow->getDocumentChangeSet(document);

        let vupdateData = [];
        for fieldName, change in changeset {
            let mapping = class1->fieldMappings[fieldName];

            // skip non embedded document identifiers
            if  ! class1->isEmbeddedDocument && ! empty mapping["id"] {
                continue;
            }

            let list = change;
            let old = list[0];
            let new_ = list[1];

            // @Inc
            if mapping["type"] === "increment" {
                if new_ === null {
                    if mapping["nullable"] === true {
                        let updateData["set"][mapping["name"]] = null;
                    } else {
                        let updateData["unset"][mapping["name"]] = true;
                    }
                } else {
                    if new_ >= old {
                        let updateData["inc"][mapping["name"]] = new_ - old;
                    } else {
                        let updateData["inc"][mapping["name"]] = (old - new_) * -1;
                    }
                }

            // @Field, @String, @Date, etc.
            } else {
                if !isset mapping["association"] {
                    if new_ || mapping["nullable"] === true {
                        let updateData["set"][mapping["name"]] = is_null(new_) ? null : Type::getType(mapping["type"])->convertToDatabaseValue(new_);
                    } else {
                        let updateData["unset"][mapping["name"]] = true;
                    }
                // @EmbedOne
                } else {
                    if isset mapping["association"] && mapping["association"] === ClassMetadataInfo::EMBED_ONE {
                        // If we have a new embedded document then lets set the whole thing
                        if new_ && this->uow->isScheduledForInsert(new_) {
                            let updateData["set"][mapping["name"]] = this->prepareEmbeddedDocumentValue(mapping, new_);

                        // If we don"t have a new value then lets unset the embedded document
                        } else {
                            if  !new_ {
                                let updateData["unset"][mapping["name"]] = true;

                            // Update existing embedded document
                            } else {
                                let update = this->prepareUpdateData(new_);
                                for cmd, values in update {
                                    for key, value in values {
                                        let updateData[cmd][mapping["name"] . "." . key] = value;
                                    }
                                }
                            }
                        }
                    
                    // @EmbedMany
                    } else {
                        if isset mapping["association"] && mapping["association"] === ClassMetadataInfo::EMBED_MANY {
                            if null !== new_ {
                                for embeddedDoc in new_ {
                                    if  !this->uow->isScheduledForInsert(embeddedDoc) {
                                        let update = this->prepareUpdateData(embeddedDoc);
                                        for cmd, values in update {
                                            for name, value in values {
                                                let updateData[cmd][mapping["name"] . "." . key . "." . name] = value;
                                            }
                                        }
                                    }
                                }
                            }
                        // @ReferenceOne
                        } else {
                            if isset mapping["association"] && mapping["association"] === ClassMetadataInfo::REFERENCE_ONE && mapping["isOwningSide"] {
                                if new_ || mapping["nullable"] === true {
                                    let updateData["set"][mapping["name"]] = (is_null(new_) ? null : this->prepareReferencedDocumentValue(mapping, new_));
                                } else {
                                    let updateData["unset"][mapping["name"]] = true;
                                }
                            // @ReferenceMany
                            } else {
                                if isset mapping["association"] && mapping["association"] === ClassMetadataInfo::REFERENCE_MANY {
                                    // Do nothing right now
                                }
                            }
                        }
                    }
                }
            }
        }
        return updateData;
    }

    /**
     * Prepares the update query to upsert a given document object in mongodb.
     *
     * @param object document
     * @return array updateData
     */
    public function prepareUpsertData(document)
    {
        var class1, changeset, updateData, fieldName, change, list, old, new_, mapping,
            update, cmd, value, values, key, embeddedDoc, name;

        let class1 = this->dm->getClassMetadata(get_class(document));
        let changeset = this->uow->getDocumentChangeSet(document);

        let updateData = [];
        for fieldName, change in changeset {
            let mapping = class1->fieldMappings[fieldName];

            let list = change;
            let old = list[0];
            let new_ = list[1];

            // @Inc
            if mapping["type"] === "increment" {
                if new_ >= old {
                    let updateData["inc"][mapping["name"]] = new_ - old;
                } else {
                    let updateData["inc"][mapping["name"]] = (old - new_) * -1;
                }

            // @Field, @String, @Date, etc.
            } else {
                if  !isset mapping["association"] {
                    if new_ || mapping["nullable"] === true {
                        let updateData["set"][mapping["name"]] = (is_null(new_) ? null : Type::getType(mapping["type"])->convertToDatabaseValue(new_));
                    }
                
                // @EmbedOne
                } else {
                    if isset mapping["association"] && mapping["association"] === ClassMetadataInfo::EMBED_ONE {
                        // If we have a new embedded document then lets set the whole thing
                        if new_ && this->uow->isScheduledForInsert(new_) {
                            let updateData["set"][mapping["name"]] = this->prepareEmbeddedDocumentValue(mapping, new_);

                        // If we don"t have a new value then do nothing on upsert
                        } else {
                            if  !new_ {

                            // Update existing embedded document
                            } else {
                                let update = this->prepareUpsertData(new_);
                                for cmd, values in update {
                                    for key, value in values {
                                        let updateData[cmd][mapping["name"] . "." . key] = value;
                                    }
                                }
                            }
                        }
                        

                    // @EmbedMany
                    } else {
                        if isset mapping["association"] && mapping["association"] === ClassMetadataInfo::EMBED_MANY && new_ {
                            for key, embeddedDoc in new_ {
                                if  !this->uow->isScheduledForInsert(embeddedDoc) {
                                    let update = this->prepareUpsertData(embeddedDoc);
                                    for cmd, values in update {
                                        for name, value in values {
                                            let updateData[cmd][mapping["name"] . "." . key . "." . name] = value;
                                        }
                                    }
                                }
                            }
                        // @ReferenceOne
                        } else {
                            if isset mapping["association"] && mapping["association"] === ClassMetadataInfo::REFERENCE_ONE && mapping["isOwningSide"] {
                                if new_ || mapping["nullable"] === true {
                                    let updateData["set"][mapping["name"]] = (is_null(new_) ? null : this->prepareReferencedDocumentValue(mapping, new_));
                                }
                            // @ReferenceMany
                            } else {
                                if isset mapping["association"] && mapping["association"] === ClassMetadataInfo::REFERENCE_MANY {
                                // Do nothing right now
                                }
                            }
                        }
                    }
                }
            }
        }

        // add discriminator if the class has one
        if isset class1->discriminatorField {
            let updateData["set"][class1->discriminatorField] = isset class1->discriminatorValue
                ? class1->discriminatorValue
                : class1->name;
        }

        return updateData;
    }

    /**
     * Returns the reference representation to be stored in MongoDB.
     *
     * If the document does not have an identifier and the mapping calls for a
     * simple reference, null may be returned.
     *
     * @param array referenceMapping
     * @param object document
     * @return array|null
     */
    public function prepareReferencedDocumentValue(array referenceMapping, document)
    {
        return this->dm->createDBRef(document, referenceMapping);
    }

    public function a_(v, pb, mapping) {
        return pb->prepareAssociatedDocumentValue(mapping, v);
    }

    /**
     * Returns the embedded document to be stored in MongoDB.
     *
     * The return value will usually be an associative array with string keys
     * corresponding to field names on the embedded document. An object may be
     * returned if the document is empty, to ensure that a BSON object will be
     * stored in lieu of an array.
     *
     * @param array embeddedMapping
     * @param object embeddedDocument
     * @return array|object
     */
    public function prepareEmbeddedDocumentValue(array embeddedMapping, embeddedDocument)
    {
        var embeddedDocumentValue, class1, mapping, rawValue, value, pb, discriminatorField,
            discriminatorValue;

        let embeddedDocumentValue = [];
        let class1 = this->dm->getClassMetadata(get_class(embeddedDocument));

        for mapping in class1->fieldMappings {
            // Skip notSaved fields
            if  !empty mapping["notSaved"] {
                continue;
            }

            // Inline ClassMetadataInfo::getFieldValue()
            let rawValue = class1->reflFields[mapping["fieldName"]]->getValue(embeddedDocument);

            let value = null;

            if rawValue !== null {
                switch isset mapping["association"] ? mapping["association"] : null {
                    // @Field, @String, @Date, etc.
                    case null:
                        let value = Type::getType(mapping["type"])->convertToDatabaseValue(rawValue);
                        break;

                    case ClassMetadataInfo::EMBED_ONE:
                    case ClassMetadataInfo::REFERENCE_ONE:
                        let value = this->prepareAssociatedDocumentValue(mapping, rawValue);
                        break;

                    case ClassMetadataInfo::EMBED_MANY:
                    case ClassMetadataInfo::REFERENCE_MANY:
                        // Skip PersistentCollections already scheduled for deletion/update
                        if (rawValue instanceof PersistentCollection) &&
                            (this->uow->isCollectionScheduledForDeletion(rawValue) ||
                             this->uow->isCollectionScheduledForUpdate(rawValue)) {
                            break;
                        }

                        let pb = this;
                        let value = rawValue->map(a_(this, pb, mapping))->toArray;

                        // Numerical reindexing may be necessary to ensure BSON array storage
                        if in_array(mapping["strategy"], ["setArray", "pushAll", "addToSet"]) {
                            let value = array_values(value);
                        }
                        break;

                    default:
                        throw new \UnexpectedValueException("Unsupported mapping association: " . mapping["association"]);
                }
            }

            // Omit non-nullable fields that would have a null value
            if value === null && mapping["nullable"] === false {
                continue;
            }

            let embeddedDocumentValue[mapping["name"]] = value;
        }

        /* Add a discriminator value if the embedded document is not mapped
         * explicitly to a targetDocument class.
         */
        if  ! isset embeddedMapping["targetDocument"] {
            let discriminatorField = embeddedMapping["discriminatorField"];
            let discriminatorValue = isset embeddedMapping["discriminatorMap"]
                ? array_search(class1->name, embeddedMapping["discriminatorMap"])
                : class1->name;

            /* If the discriminator value was not found in the map, use the full
             * class name. In the future, it may be preferable to throw an
             * exception here (perhaps based on some strictness option).
             *
             * @see DocumentManager::createDBRef()
             */
            if discriminatorValue === false {
                let discriminatorValue = class1->name;
            }

            let embeddedDocumentValue[discriminatorField] = discriminatorValue;
        }

        /* If the class has a discriminator (field and value), use it. A child
         * class that is not defined in the discriminator map may only have a
         * discriminator field and no value, so default to the full class name.
         */
        if isset class1->discriminatorField {
            let embeddedDocumentValue[class1->discriminatorField] = isset class1->discriminatorValue
                ? class1->discriminatorValue
                : class1->name;
        }

        // Ensure empty embedded documents are stored as BSON objects
        if empty embeddedDocumentValue {
            return (object) embeddedDocumentValue;
        }

        /* @todo Consider always casting the return value to an object, or
         * building embeddedDocumentValue as an object instead of an array, to
         * handle the edge case where all database field names are sequential,
         * numeric keys.
         */
        return embeddedDocumentValue;
    }

    /*
     * Returns the embedded document or reference representation to be stored.
     *
     * @param array mapping
     * @param object document
     * @return array|object|null
     */
    public function prepareAssociatedDocumentValue(array mapping, document)
    {
        if isset mapping["embedded"] {
            return this->prepareEmbeddedDocumentValue(mapping, document);
        }

        if isset mapping["reference"] {
            return this->prepareReferencedDocumentValue(mapping, document);
        }

        throw new \InvalidArgumentException("Mapping is neither embedded nor reference.");
    }

    /**
     * @param object document
     * @return boolean
     */
    private function isScheduledForInsert(document)
    {
        return this->uow->isScheduledForInsert(document)
            || this->uow->getDocumentPersister(get_class(document))->isQueuedForInsert(document);
    }
}