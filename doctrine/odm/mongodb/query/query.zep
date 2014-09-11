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

namespace Doctrine\ODM\MongoDB\Query;

use Doctrine\MongoDB\Collection;
use Doctrine\MongoDB\Cursor as BaseCursor;
use Doctrine\MongoDB\EagerCursor as BaseEagerCursor;
use Doctrine\MongoDB\Iterator;
use Doctrine\ODM\MongoDB\Cursor;
use Doctrine\ODM\MongoDB\DocumentManager;
use Doctrine\ODM\MongoDB\EagerCursor;
use Doctrine\ODM\MongoDB\Mapping\ClassMetadata;
use Doctrine\ODM\MongoDB\MongoDBException;

/**
 * ODM Query wraps the raw Doctrine MongoDB queries to add additional functionality
 * and to hydrate the raw arrays of data to Doctrine document objects.
 *
 * @since       1.0
 * @author      Jonathan H. Wage <jonwage@gmail.com>
 */
class Query extends \Doctrine\MongoDB\Query\Query
{
    const HINT_REFRESH = 1;
    const HINT_SLAVE_OKAY = 2;
    const HINT_READ_PREFERENCE = 3;
    const HINT_READ_PREFERENCE_TAGS = 4;

    /**
     * The DocumentManager instance.
     *
     * @var DocumentManager
     */
    private dm;

    /**
     * The ClassMetadata instance.
     *
     * @var ClassMetadata
     */
    private class1;

    /**
     * Whether to hydrate results as document class instances.
     *
     * @var boolean
     */
    private hydrate = true;

    /**
     * Array of primer Closure instances.
     *
     * @var array
     */
    private primers = [];

    /**
     * Whether or not to require indexes.
     *
     * @var boolean
     */
    private requireIndexes;

    /**
     * Hints for UnitOfWork behavior.
     *
     * @var array
     */
    private unitOfWorkHints = [];

    /**
     * Constructor.
     *
     * @param DocumentManager dm
     * @param ClassMetadata class
     * @param Collection collection
     * @param array query
     * @param array options
     * @param boolean hydrate
     * @param boolean refresh
     * @param array primers
     * @param null requireIndexes
     */
    public function __construct( dm,  class1,  collection, array query = [], array options = [], hydrate = true, refresh = false, array primers = [], requireIndexes = null)
    {
        parent::__construct(collection, query, options);
        let this->dm = dm;
        let this->class1 = class1;
        let this->hydrate = hydrate;
        let this->primers = array_filter(primers);
        let this->requireIndexes = requireIndexes;

        this->setRefresh(refresh);

        if isset query["slaveOkay"] {
            let this->unitOfWorkHints[self::HINT_SLAVE_OKAY] = query["slaveOkay"];
        }

        if isset query["readPreference"] {
            let this->unitOfWorkHints[self::HINT_READ_PREFERENCE] = query["readPreference"];
            let this->unitOfWorkHints[self::HINT_READ_PREFERENCE_TAGS] = query["readPreferenceTags"];
        }
    }

    /**
     * Gets the DocumentManager instance.
     *
     * @return DocumentManager dm
     */
    public function getDocumentManager()
    {
        return this->dm;
    }

    /**
     * Gets the ClassMetadata instance.
     *
     * @return ClassMetadata class
     */
    public function getClass()
    {
        return this->class1;
    }

    /**
     * Sets whether or not to hydrate the documents to objects.
     *
     * @param boolean hydrate
     */
    public function setHydrate(hydrate)
    {
        let this->hydrate = (boolean) hydrate;
    }

    /**
     * Set whether to refresh hydrated documents that are already in the
     * identity map.
     *
     * This option has no effect if hydration is disabled.
     *
     * @param boolean refresh
     */
    public function setRefresh(refresh)
    {
        let this->unitOfWorkHints[Query::HINT_REFRESH] = (boolean) refresh;
    }

    /**
     * Gets the fields involved in this query.
     *
     * @return array fields An array of fields names used in this query.
     */
    public function getFieldsInQuery()
    {
        var query, sort, extractor;

        let query = isset this->query["query"] ? this->query["query"] : [];
        let sort = isset this->query["sort"] ? this->query["sort"] : [];

        let extractor = new FieldExtractor(query, sort);
        return extractor->getFields();
    }

    /**
     * Check if this query is indexed.
     *
     * @return bool
     */
    public function isIndexed()
    {
        var fields, field;

        let fields = this->getFieldsInQuery();
        for field in fields {
            if  !this->collection->isFieldIndexed(field) {
                return false;
            }
        }
        return true;
    }

    /**
     * Gets an array of the unindexed fields in this query.
     *
     * @return array
     */
    public function getUnindexedFields()
    {
        var unindexedFields, fields, field;

        let unindexedFields = [];
        let fields = this->getFieldsInQuery();
        for field in fields {
            if  !this->collection->isFieldIndexed(field) {
                let unindexedFields[] = field;
            }
        }
        return unindexedFields;
    }

    /**
     * Execute the query and returns the results.
     *
     * @throws \Doctrine\ODM\MongoDB\MongoDBException
     * @return mixed
     */
    public function execute()
    {
        var results, uow, key, result, document, referencePrimer, fieldName, primer, documents;

        if this->isIndexRequired() && ! this->isIndexed() {
            throw MongoDBException::queryNotIndexed(this->class1->name, this->getUnindexedFields());
        }

        let results = parent::execute();

        if  !this->hydrate {
            return results;
        }

        let uow = this->dm->getUnitOfWork();

        /* A geoNear command returns an ArrayIterator, where each result is an
         * object with "dis" (computed distance) and "obj" (original document)
         * properties. If hydration is enabled, eagerly hydrate these results.
         *
         * Other commands results are not handled, since their results may not
         * resemble documents in the collection.
         */
        if this->query["type"] === \Doctrine\MongoDB\Query\Query::TYPE_GEO_NEAR {
            for key, result in results {
                let document = result["obj"];
                if this->class1->distance !== null {
                    let document[this->class1->distance] = result["dis"];
                }
                let results[key] = uow->getOrCreateDocument(this->class1->name, document, this->unitOfWorkHints);
            }
            results->reset();
        }

        /* If a single document is returned from a findAndModify command and it
         * includes the identifier field, attempt hydration.
         */
        if (this->query["type"] === \Doctrine\MongoDB\Query\Query::TYPE_FIND_AND_UPDATE ||
             this->query["type"] === \Doctrine\MongoDB\Query\Query::TYPE_FIND_AND_REMOVE) &&
            is_array(results) && isset results["_id"] {

            let results = uow->getOrCreateDocument(this->class1->name, results, this->unitOfWorkHints);
        }

        if  !empty this->primers {
            let referencePrimer = new ReferencePrimer(this->dm, uow);

            for fieldName, primer in this->primers {
                let primer = is_callable(primer) ? primer : null;
                let documents = results instanceof Iterator ? results : [results];
                referencePrimer->primeReferences(this->class1, documents, fieldName, this->unitOfWorkHints, primer);
            }
        }

        return results;
    }

    /**
     * Prepare the Cursor returned by {@link Query::execute()}.
     *
     * This method will wrap the base Cursor with an ODM Cursor or EagerCursor,
     * and set the hydrate option and UnitOfWork hints. This occurs in addition
     * to any preparation done by the base Query class.
     *
     * @see \Doctrine\MongoDB\Cursor::prepareCursor()
     * @param BaseCursor cursor
     * @return Cursor|EagerCursor
     */
    protected function prepareCursor( cursor)
    {
        let cursor = parent::prepareCursor(cursor);

        // Unwrap a base EagerCursor
        if cursor instanceof BaseEagerCursor {
            let cursor = cursor->getCursor();
        }

        // Convert the base Cursor into an ODM Cursor
        let cursor = new Cursor(cursor, this->dm->getUnitOfWork(), this->class1);

        // Wrap ODM Cursor with EagerCursor
        if  !empty this->query["eagerCursor"] {
            let cursor = new EagerCursor(cursor, this->dm->getUnitOfWork(), this->class1);
        }

        cursor->hydrate(this->hydrate);
        cursor->setHints(this->unitOfWorkHints);

        return cursor;
    }

    /**
     * Return whether queries on this document should require indexes.
     *
     * @return boolean
     */
    private function isIndexRequired()
    {
        return this->requireIndexes !== null ? this->requireIndexes : this->class1->requireIndexes;
    }
}
