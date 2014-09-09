
#ifdef HAVE_CONFIG_H
#include "../../../ext_config.h"
#endif

#include <php.h>
#include "../../../php_ext.h"
#include "../../../ext.h"

#include <Zend/zend_operators.h>
#include <Zend/zend_exceptions.h>
#include <Zend/zend_interfaces.h>

#include "kernel/main.h"
#include "kernel/object.h"
#include "kernel/fcall.h"
#include "kernel/memory.h"
#include "kernel/operators.h"
#include "kernel/string.h"
#include "kernel/array.h"
#include "kernel/exception.h"


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
/*use Doctrine\Common\EventManager;
use Doctrine\Common\Persistence\ObjectManager;
use Doctrine\MongoDB\Connection;
use Doctrine\ODM\MongoDB\Hydrator\HydratorFactory;
use Doctrine\ODM\MongoDB\Mapping\ClassMetadata;
use Doctrine\ODM\MongoDB\Mapping\ClassMetadataFactory;
use Doctrine\ODM\MongoDB\Proxy\ProxyFactory;
use Doctrine\ODM\MongoDB\Query\FilterCollection;*/
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
ZEPHIR_INIT_CLASS(Doctrine_ODM_MongoDB_DocumentManager) {

	ZEPHIR_REGISTER_CLASS(Doctrine\\ODM\\MongoDB, DocumentManager, doctrine, odm_mongodb_documentmanager, doctrine_odm_mongodb_documentmanager_method_entry, 0);

	/**
	 * The Doctrine MongoDB connection instance.
	 *
	 * @var \Doctrine\MongoDB\Connection
	 */
	zend_declare_property_null(doctrine_odm_mongodb_documentmanager_ce, SL("connection"), ZEND_ACC_PRIVATE TSRMLS_CC);

	/**
	 * The used Configuration.
	 *
	 * @var \Doctrine\ODM\MongoDB\Configuration
	 */
	zend_declare_property_null(doctrine_odm_mongodb_documentmanager_ce, SL("config"), ZEND_ACC_PRIVATE TSRMLS_CC);

	/**
	 * The metadata factory, used to retrieve the ODM metadata of document classes.
	 *
	 * @var \Doctrine\ODM\MongoDB\Mapping\ClassMetadataFactory
	 */
	zend_declare_property_null(doctrine_odm_mongodb_documentmanager_ce, SL("metadataFactory"), ZEND_ACC_PRIVATE TSRMLS_CC);

	/**
	 * The DocumentRepository instances.
	 *
	 * @var array
	 */
	zend_declare_property_null(doctrine_odm_mongodb_documentmanager_ce, SL("repositories"), ZEND_ACC_PRIVATE TSRMLS_CC);

	/**
	 * The UnitOfWork used to coordinate object-level transactions.
	 *
	 * @var UnitOfWork
	 */
	zend_declare_property_null(doctrine_odm_mongodb_documentmanager_ce, SL("unitOfWork"), ZEND_ACC_PRIVATE TSRMLS_CC);

	/**
	 * The event manager that is the central point of the event system.
	 *
	 * @var \Doctrine\Common\EventManager
	 */
	zend_declare_property_null(doctrine_odm_mongodb_documentmanager_ce, SL("eventManager"), ZEND_ACC_PRIVATE TSRMLS_CC);

	/**
	 * The Hydrator factory instance.
	 *
	 * @var HydratorFactory
	 */
	zend_declare_property_null(doctrine_odm_mongodb_documentmanager_ce, SL("hydratorFactory"), ZEND_ACC_PRIVATE TSRMLS_CC);

	/**
	 * The Proxy factory instance.
	 *
	 * @var ProxyFactory
	 */
	zend_declare_property_null(doctrine_odm_mongodb_documentmanager_ce, SL("proxyFactory"), ZEND_ACC_PRIVATE TSRMLS_CC);

	/**
	 * SchemaManager instance
	 *
	 * @var SchemaManager
	 */
	zend_declare_property_null(doctrine_odm_mongodb_documentmanager_ce, SL("schemaManager"), ZEND_ACC_PRIVATE TSRMLS_CC);

	/**
	 * Array of cached document database instances that are lazily loaded.
	 *
	 * @var array
	 */
	zend_declare_property_null(doctrine_odm_mongodb_documentmanager_ce, SL("documentDatabases"), ZEND_ACC_PRIVATE TSRMLS_CC);

	/**
	 * Array of cached document collection instances that are lazily loaded.
	 *
	 * @var array
	 */
	zend_declare_property_null(doctrine_odm_mongodb_documentmanager_ce, SL("documentCollections"), ZEND_ACC_PRIVATE TSRMLS_CC);

	/**
	 * Whether the DocumentManager is closed or not.
	 *
	 * @var bool
	 */
	zend_declare_property_bool(doctrine_odm_mongodb_documentmanager_ce, SL("closed"), 0, ZEND_ACC_PRIVATE TSRMLS_CC);

	/**
	 * Collection of query filters.
	 *
	 * @var \Doctrine\ODM\MongoDB\Query\FilterCollection
	 */
	zend_declare_property_null(doctrine_odm_mongodb_documentmanager_ce, SL("filterCollection"), ZEND_ACC_PRIVATE TSRMLS_CC);

	return SUCCESS;

}

/**
 * Creates a new Document that operates on the given Mongo connection
 * and uses the given Configuration.
 *
 * @param \Doctrine\MongoDB\Connection|null $conn
 * @param Configuration|null $config
 * @param \Doctrine\Common\EventManager|null $eventManager
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, __construct) {

	zend_class_entry *_0, *_2, *_5, *_7;
	int ZEPHIR_LAST_CALL_STATUS;
	zval *conn, *config, *eventManager, *metadataFactoryClassName = NULL, *cacheDriver = NULL, *hydratorDir = NULL, *hydratorNs = NULL, *unitOfWork, *metadataFactory, *hydratorFactory, *_1 = NULL, *_3, *_4, *_6, *_8 = NULL, *_9 = NULL, *_10 = NULL;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 3, 0, &conn, &config, &eventManager);



	zephir_update_property_this(this_ptr, SL("config"), config TSRMLS_CC);
	zephir_update_property_this(this_ptr, SL("eventManager"), eventManager TSRMLS_CC);
	zephir_update_property_this(this_ptr, SL("connection"), conn TSRMLS_CC);
	ZEPHIR_CALL_METHOD(&metadataFactoryClassName, config, "getclassmetadatafactoryname",  NULL);
	zephir_check_call_status();
	ZEPHIR_INIT_VAR(metadataFactory);
	_0 = zend_fetch_class(Z_STRVAL_P(metadataFactoryClassName), Z_STRLEN_P(metadataFactoryClassName), ZEND_FETCH_CLASS_AUTO TSRMLS_CC);
	object_init_ex(metadataFactory, _0);
	if (zephir_has_constructor(metadataFactory TSRMLS_CC)) {
		ZEPHIR_CALL_METHOD(NULL, metadataFactory, "__construct", NULL);
		zephir_check_call_status();
	}
	zephir_update_property_this(this_ptr, SL("metadataFactory"), metadataFactory TSRMLS_CC);
	ZEPHIR_CALL_METHOD(NULL, metadataFactory, "setdocumentmanager", NULL, this_ptr);
	zephir_check_call_status();
	ZEPHIR_CALL_METHOD(NULL, metadataFactory, "setconfiguration", NULL, config);
	zephir_check_call_status();
	ZEPHIR_CALL_METHOD(&cacheDriver, config, "getmetadatacacheimpl",  NULL);
	zephir_check_call_status();
	if (zephir_is_true(cacheDriver)) {
		ZEPHIR_CALL_METHOD(NULL, metadataFactory, "setcachedriver", NULL, cacheDriver);
		zephir_check_call_status();
	}
	ZEPHIR_CALL_METHOD(&hydratorDir, config, "gethydratordir",  NULL);
	zephir_check_call_status();
	ZEPHIR_CALL_METHOD(&hydratorNs, config, "gethydratornamespace",  NULL);
	zephir_check_call_status();
	ZEPHIR_INIT_VAR(hydratorFactory);
	object_init_ex(hydratorFactory, doctrine_odm_mongodb_hydrator_hydratorfactory_ce);
	ZEPHIR_CALL_METHOD(&_1, config, "getautogeneratehydratorclasses",  NULL);
	zephir_check_call_status();
	ZEPHIR_CALL_METHOD(NULL, hydratorFactory, "__construct", NULL, this_ptr, eventManager, hydratorDir, hydratorNs, _1);
	zephir_check_call_status();
	zephir_update_property_this(this_ptr, SL("hydratorFactory"), hydratorFactory TSRMLS_CC);
	ZEPHIR_INIT_VAR(unitOfWork);
	_2 = zend_fetch_class(SL("Doctrine\\ODM\\MongoDB\\UnitOfWork"), ZEND_FETCH_CLASS_AUTO TSRMLS_CC);
	object_init_ex(unitOfWork, _2);
	if (zephir_has_constructor(unitOfWork TSRMLS_CC)) {
		ZEPHIR_CALL_METHOD(NULL, unitOfWork, "__construct", NULL, this_ptr, eventManager, hydratorFactory);
		zephir_check_call_status();
	}
	zephir_update_property_this(this_ptr, SL("unitOfWork"), unitOfWork TSRMLS_CC);
	_3 = zephir_fetch_nproperty_this(this_ptr, SL("hydratorFactory"), PH_NOISY_CC);
	ZEPHIR_CALL_METHOD(NULL, _3, "setunitofwork", NULL, unitOfWork);
	zephir_check_call_status();
	ZEPHIR_INIT_VAR(_4);
	_5 = zend_fetch_class(SL("Doctrine\\ODM\\MongoDB\\SchemaManager"), ZEND_FETCH_CLASS_AUTO TSRMLS_CC);
	object_init_ex(_4, _5);
	if (zephir_has_constructor(_4 TSRMLS_CC)) {
		ZEPHIR_CALL_METHOD(NULL, _4, "__construct", NULL, this_ptr, metadataFactory);
		zephir_check_call_status();
	}
	zephir_update_property_this(this_ptr, SL("schemaManager"), _4 TSRMLS_CC);
	ZEPHIR_INIT_VAR(_6);
	_7 = zend_fetch_class(SL("Doctrine\\ODM\\MongoDB\\Proxy\\ProxyFactory"), ZEND_FETCH_CLASS_AUTO TSRMLS_CC);
	object_init_ex(_6, _7);
	if (zephir_has_constructor(_6 TSRMLS_CC)) {
		ZEPHIR_CALL_METHOD(&_8, config, "getproxydir",  NULL);
		zephir_check_call_status();
		ZEPHIR_CALL_METHOD(&_9, config, "getproxynamespace",  NULL);
		zephir_check_call_status();
		ZEPHIR_CALL_METHOD(&_10, config, "getautogenerateproxyclasses",  NULL);
		zephir_check_call_status();
		ZEPHIR_CALL_METHOD(NULL, _6, "__construct", NULL, this_ptr, _8, _9, _10);
		zephir_check_call_status();
	}
	zephir_update_property_this(this_ptr, SL("proxyFactory"), _6 TSRMLS_CC);
	ZEPHIR_MM_RESTORE();

}

/**
 * Gets the proxy factory used by the DocumentManager to create document proxies.
 *
 * @return ProxyFactory
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getProxyFactory) {


	RETURN_MEMBER(this_ptr, "proxyFactory");

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
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, create) {

	int ZEPHIR_LAST_CALL_STATUS;
	zval *conn = NULL, *config = NULL, *eventManager = NULL;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 0, 3, &conn, &config, &eventManager);

	if (!conn) {
		conn = ZEPHIR_GLOBAL(global_null);
	}
	if (!config) {
		config = ZEPHIR_GLOBAL(global_null);
	}
	if (!eventManager) {
		eventManager = ZEPHIR_GLOBAL(global_null);
	}


	object_init_ex(return_value, doctrine_odm_mongodb_documentmanager_ce);
	ZEPHIR_CALL_METHOD(NULL, return_value, "__construct", NULL, conn, config, eventManager);
	zephir_check_call_status();
	RETURN_MM();

}

/**
 * Gets the EventManager used by the DocumentManager.
 *
 * @return \Doctrine\Common\EventManager
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getEventManager) {


	RETURN_MEMBER(this_ptr, "eventManager");

}

/**
 * Gets the PHP Mongo instance that this DocumentManager wraps.
 *
 * @return \Doctrine\MongoDB\Connection
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getConnection) {


	RETURN_MEMBER(this_ptr, "connection");

}

/**
 * Gets the metadata factory used to gather the metadata of classes.
 *
 * @return \Doctrine\ODM\MongoDB\Mapping\ClassMetadataFactory
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getMetadataFactory) {


	RETURN_MEMBER(this_ptr, "metadataFactory");

}

/**
 * Helper method to initialize a lazy loading proxy or persistent collection.
 *
 * This method is a no-op for other objects.
 *
 * @param object $obj
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, initializeObject) {

	int ZEPHIR_LAST_CALL_STATUS;
	zval *obj, *_0;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 1, 0, &obj);



	_0 = zephir_fetch_nproperty_this(this_ptr, SL("unitOfWork"), PH_NOISY_CC);
	ZEPHIR_CALL_METHOD(NULL, _0, "initializeobject", NULL, obj);
	zephir_check_call_status();
	ZEPHIR_MM_RESTORE();

}

/**
 * Gets the UnitOfWork used by the DocumentManager to coordinate operations.
 *
 * @return UnitOfWork
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getUnitOfWork) {


	RETURN_MEMBER(this_ptr, "unitOfWork");

}

/**
 * Gets the Hydrator factory used by the DocumentManager to generate and get hydrators
 * for each type of document.
 *
 * @return \Doctrine\ODM\MongoDB\Hydrator\HydratorInterface
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getHydratorFactory) {


	RETURN_MEMBER(this_ptr, "hydratorFactory");

}

/**
 * Returns SchemaManager, used to create/drop indexes/collections/databases.
 *
 * @return \Doctrine\ODM\MongoDB\SchemaManager
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getSchemaManager) {


	RETURN_MEMBER(this_ptr, "schemaManager");

}

/**
 * Returns the metadata for a class.
 *
 * @param string $className The class name.
 * @return \Doctrine\ODM\MongoDB\Mapping\ClassMetadata
 * @internal Performance-sensitive method.
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getClassMetadata) {

	int ZEPHIR_LAST_CALL_STATUS;
	zval *className, *newClassName = NULL, _0, *_1;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 1, 0, &className);



	if (zephir_start_with_str(className, SL("\\"))) {
		ZEPHIR_INIT_VAR(newClassName);
		ZEPHIR_SINIT_VAR(_0);
		ZVAL_STRING(&_0, "\\", 0);
		zephir_fast_trim(newClassName, className, &_0, ZEPHIR_TRIM_LEFT TSRMLS_CC);
	} else {
		ZEPHIR_CPY_WRT(newClassName, className);
	}
	_1 = zephir_fetch_nproperty_this(this_ptr, SL("metadataFactory"), PH_NOISY_CC);
	ZEPHIR_RETURN_CALL_METHOD(_1, "getmetadatafor", NULL, newClassName);
	zephir_check_call_status();
	RETURN_MM();

}

/**
 * Returns the MongoDB instance for a class.
 *
 * @param string $className The class name.
 * @return \Doctrine\MongoDB\Database
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getDocumentDatabase) {

	int ZEPHIR_LAST_CALL_STATUS;
	zval *className, *newClassName = NULL, *documentDatabase = NULL, *db = NULL, *metadata = NULL, _0, *_1, *_2, *_3 = NULL, *_4, *_5;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 1, 0, &className);



	if (zephir_start_with_str(className, SL("\\"))) {
		ZEPHIR_INIT_VAR(newClassName);
		ZEPHIR_SINIT_VAR(_0);
		ZVAL_STRING(&_0, "\\", 0);
		zephir_fast_trim(newClassName, className, &_0, ZEPHIR_TRIM_LEFT TSRMLS_CC);
	} else {
		ZEPHIR_CPY_WRT(newClassName, className);
	}
	ZEPHIR_OBS_VAR(documentDatabase);
	_1 = zephir_fetch_nproperty_this(this_ptr, SL("documentDatabases"), PH_NOISY_CC);
	if (zephir_array_isset_fetch(&documentDatabase, _1, newClassName, 0 TSRMLS_CC)) {
		RETURN_CCTOR(documentDatabase);
	}
	_2 = zephir_fetch_nproperty_this(this_ptr, SL("metadataFactory"), PH_NOISY_CC);
	ZEPHIR_CALL_METHOD(&metadata, _2, "getmetadatafor", NULL, newClassName);
	zephir_check_call_status();
	ZEPHIR_CALL_METHOD(&db, metadata, "getdatabase",  NULL);
	zephir_check_call_status();
	ZEPHIR_INIT_VAR(_3);
	if (zephir_is_true(db)) {
		ZEPHIR_CPY_WRT(_3, db);
	} else {
		_4 = zephir_fetch_nproperty_this(this_ptr, SL("config"), PH_NOISY_CC);
		ZEPHIR_CALL_METHOD(&_3, _4, "getdefaultdb",  NULL);
		zephir_check_call_status();
	}
	ZEPHIR_CPY_WRT(db, _3);
	ZEPHIR_INIT_LNVAR(_3);
	if (zephir_is_true(db)) {
		ZEPHIR_CPY_WRT(_3, db);
	} else {
		ZEPHIR_INIT_BNVAR(_3);
		ZVAL_STRING(_3, "doctrine", 1);
	}
	ZEPHIR_CPY_WRT(db, _3);
	_5 = zephir_fetch_nproperty_this(this_ptr, SL("connection"), PH_NOISY_CC);
	ZEPHIR_CALL_METHOD(&documentDatabase, _5, "selectdatabase", NULL, db);
	zephir_check_call_status();
	zephir_update_property_array(this_ptr, SL("documentDatabases"), newClassName, documentDatabase TSRMLS_CC);
	RETURN_CCTOR(documentDatabase);

}

/**
 * Gets the array of instantiated document database instances.
 *
 * @return array
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getDocumentDatabases) {


	RETURN_MEMBER(this_ptr, "documentDatabases");

}

/**
 * Returns the MongoCollection instance for a class.
 *
 * @param string $className The class name.
 * @throws MongoDBException When the $className param is not mapped to a collection
 * @return \Doctrine\MongoDB\Collection
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getDocumentCollection) {

	zephir_nts_static zephir_fcall_cache_entry *_3 = NULL;
	int ZEPHIR_LAST_CALL_STATUS;
	zval *className, *newClassName = NULL, *collectionName = NULL, *collection = NULL, *db = NULL, *metadata = NULL, _0, *_1, *_2, *_4 = NULL, *_5, *_6, *_7, *_8;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 1, 0, &className);



	if (zephir_start_with_str(className, SL("\\"))) {
		ZEPHIR_INIT_VAR(newClassName);
		ZEPHIR_SINIT_VAR(_0);
		ZVAL_STRING(&_0, "\\", 0);
		zephir_fast_trim(newClassName, className, &_0, ZEPHIR_TRIM_LEFT TSRMLS_CC);
	} else {
		ZEPHIR_CPY_WRT(newClassName, className);
	}
	_1 = zephir_fetch_nproperty_this(this_ptr, SL("metadataFactory"), PH_NOISY_CC);
	ZEPHIR_CALL_METHOD(&metadata, _1, "getmetadatafor", NULL, newClassName);
	zephir_check_call_status();
	ZEPHIR_CALL_METHOD(&collectionName, metadata, "getcollection",  NULL);
	zephir_check_call_status();
	if (!(zephir_is_true(collectionName))) {
		ZEPHIR_THROW_EXCEPTION_DEBUG_STR(zend_exception_get_default(TSRMLS_C), "?", "doctrine/odm/mongodb/documentmanager.zep", 369);
		return;
	}
	ZEPHIR_OBS_VAR(collection);
	_2 = zephir_fetch_nproperty_this(this_ptr, SL("documentCollections"), PH_NOISY_CC);
	if (!(zephir_array_isset_fetch(&collection, _2, newClassName, 0 TSRMLS_CC))) {
		ZEPHIR_CALL_METHOD(&db, this_ptr, "getdocumentdatabase", &_3, newClassName);
		zephir_check_call_status();
		ZEPHIR_CALL_METHOD(&_4, metadata, "isfile",  NULL);
		zephir_check_call_status();
		if (zephir_is_true(_4)) {
			ZEPHIR_CALL_METHOD(&collection, db, "getgridfs", NULL, collectionName);
			zephir_check_call_status();
		} else {
			ZEPHIR_CALL_METHOD(&collection, db, "selectcollection", NULL, collectionName);
			zephir_check_call_status();
		}
		zephir_update_property_array(this_ptr, SL("documentCollections"), newClassName, collection TSRMLS_CC);
	}
	ZEPHIR_OBS_VAR(_5);
	zephir_read_property(&_5, metadata, SL("slaveOkay"), PH_NOISY_CC);
	if (Z_TYPE_P(_5) != IS_NULL) {
		ZEPHIR_OBS_VAR(_6);
		zephir_read_property(&_6, metadata, SL("slaveOkay"), PH_NOISY_CC);
		ZEPHIR_CALL_METHOD(NULL, collection, "setslaveokay", NULL, _6);
		zephir_check_call_status();
	}
	_7 = zephir_fetch_nproperty_this(this_ptr, SL("documentCollections"), PH_NOISY_CC);
	zephir_array_fetch(&_8, _7, className, PH_NOISY | PH_READONLY, "doctrine/odm/mongodb/documentmanager.zep", 382 TSRMLS_CC);
	RETURN_CTOR(_8);

}

/**
 * Gets the array of instantiated document collection instances.
 *
 * @return array
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getDocumentCollections) {


	RETURN_MEMBER(this_ptr, "documentCollections");

}

/**
 * Create a new Query instance for a class.
 *
 * @param string $documentName The document class name.
 * @return Query\Builder
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, createQueryBuilder) {

	int ZEPHIR_LAST_CALL_STATUS;
	zend_class_entry *_0;
	zval *documentName = NULL;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 0, 1, &documentName);

	if (!documentName) {
		documentName = ZEPHIR_GLOBAL(global_null);
	}


	_0 = zend_fetch_class(SL("Doctrine\\ODM\\MongoDB\\Query\\Builder"), ZEND_FETCH_CLASS_AUTO TSRMLS_CC);
	object_init_ex(return_value, _0);
	if (zephir_has_constructor(return_value TSRMLS_CC)) {
		ZEPHIR_CALL_METHOD(NULL, return_value, "__construct", NULL, this_ptr, documentName);
		zephir_check_call_status();
	}
	RETURN_MM();

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
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, persist) {

	zephir_nts_static zephir_fcall_cache_entry *_2 = NULL;
	int ZEPHIR_LAST_CALL_STATUS;
	zval *document, *_0, *_1, *_3;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 1, 0, &document);



	if (!(Z_TYPE_P(document) == IS_OBJECT)) {
		ZEPHIR_INIT_VAR(_0);
		object_init_ex(_0, spl_ce_InvalidArgumentException);
		ZEPHIR_INIT_VAR(_1);
		zephir_gettype(_1, document TSRMLS_CC);
		ZEPHIR_CALL_METHOD(NULL, _0, "__construct", NULL, _1);
		zephir_check_call_status();
		zephir_throw_exception_debug(_0, "doctrine/odm/mongodb/documentmanager.zep", 421 TSRMLS_CC);
		ZEPHIR_MM_RESTORE();
		return;
	}
	ZEPHIR_CALL_METHOD(NULL, this_ptr, "errorifclosed", &_2);
	zephir_check_call_status();
	_3 = zephir_fetch_nproperty_this(this_ptr, SL("unitOfWork"), PH_NOISY_CC);
	ZEPHIR_CALL_METHOD(NULL, _3, "persist", NULL, document);
	zephir_check_call_status();
	ZEPHIR_MM_RESTORE();

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
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, remove) {

	zephir_nts_static zephir_fcall_cache_entry *_2 = NULL;
	int ZEPHIR_LAST_CALL_STATUS;
	zval *document, *_0, *_1, *_3;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 1, 0, &document);



	if (!(Z_TYPE_P(document) == IS_OBJECT)) {
		ZEPHIR_INIT_VAR(_0);
		object_init_ex(_0, spl_ce_InvalidArgumentException);
		ZEPHIR_INIT_VAR(_1);
		zephir_gettype(_1, document TSRMLS_CC);
		ZEPHIR_CALL_METHOD(NULL, _0, "__construct", NULL, _1);
		zephir_check_call_status();
		zephir_throw_exception_debug(_0, "doctrine/odm/mongodb/documentmanager.zep", 439 TSRMLS_CC);
		ZEPHIR_MM_RESTORE();
		return;
	}
	ZEPHIR_CALL_METHOD(NULL, this_ptr, "errorifclosed", &_2);
	zephir_check_call_status();
	_3 = zephir_fetch_nproperty_this(this_ptr, SL("unitOfWork"), PH_NOISY_CC);
	ZEPHIR_CALL_METHOD(NULL, _3, "remove", NULL, document);
	zephir_check_call_status();
	ZEPHIR_MM_RESTORE();

}

/**
 * Refreshes the persistent state of a document from the database,
 * overriding any local changes that have not yet been persisted.
 *
 * @param object $document The document to refresh.
 * @throws \InvalidArgumentException When the given $document param is not an object
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, refresh) {

	zephir_nts_static zephir_fcall_cache_entry *_2 = NULL;
	int ZEPHIR_LAST_CALL_STATUS;
	zval *document, *_0, *_1, *_3;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 1, 0, &document);



	if (!(Z_TYPE_P(document) == IS_OBJECT)) {
		ZEPHIR_INIT_VAR(_0);
		object_init_ex(_0, spl_ce_InvalidArgumentException);
		ZEPHIR_INIT_VAR(_1);
		zephir_gettype(_1, document TSRMLS_CC);
		ZEPHIR_CALL_METHOD(NULL, _0, "__construct", NULL, _1);
		zephir_check_call_status();
		zephir_throw_exception_debug(_0, "doctrine/odm/mongodb/documentmanager.zep", 455 TSRMLS_CC);
		ZEPHIR_MM_RESTORE();
		return;
	}
	ZEPHIR_CALL_METHOD(NULL, this_ptr, "errorifclosed", &_2);
	zephir_check_call_status();
	_3 = zephir_fetch_nproperty_this(this_ptr, SL("unitOfWork"), PH_NOISY_CC);
	ZEPHIR_CALL_METHOD(NULL, _3, "refresh", NULL, document);
	zephir_check_call_status();
	ZEPHIR_MM_RESTORE();

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
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, detach) {

	int ZEPHIR_LAST_CALL_STATUS;
	zval *document, *_0, *_1, *_2;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 1, 0, &document);



	if (!(Z_TYPE_P(document) == IS_OBJECT)) {
		ZEPHIR_INIT_VAR(_0);
		object_init_ex(_0, spl_ce_InvalidArgumentException);
		ZEPHIR_INIT_VAR(_1);
		zephir_gettype(_1, document TSRMLS_CC);
		ZEPHIR_CALL_METHOD(NULL, _0, "__construct", NULL, _1);
		zephir_check_call_status();
		zephir_throw_exception_debug(_0, "doctrine/odm/mongodb/documentmanager.zep", 474 TSRMLS_CC);
		ZEPHIR_MM_RESTORE();
		return;
	}
	_2 = zephir_fetch_nproperty_this(this_ptr, SL("unitOfWork"), PH_NOISY_CC);
	ZEPHIR_CALL_METHOD(NULL, _2, "detach", NULL, document);
	zephir_check_call_status();
	ZEPHIR_MM_RESTORE();

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
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, merge) {

	zephir_nts_static zephir_fcall_cache_entry *_2 = NULL;
	int ZEPHIR_LAST_CALL_STATUS;
	zval *document, *_0, *_1, *_3;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 1, 0, &document);



	if (!Z_TYPE_P(document) == IS_OBJECT) {
		ZEPHIR_INIT_VAR(_0);
		object_init_ex(_0, spl_ce_InvalidArgumentException);
		ZEPHIR_INIT_VAR(_1);
		zephir_gettype(_1, document TSRMLS_CC);
		ZEPHIR_CALL_METHOD(NULL, _0, "__construct", NULL, _1);
		zephir_check_call_status();
		zephir_throw_exception_debug(_0, "doctrine/odm/mongodb/documentmanager.zep", 492 TSRMLS_CC);
		ZEPHIR_MM_RESTORE();
		return;
	}
	ZEPHIR_CALL_METHOD(NULL, this_ptr, "errorifclosed", &_2);
	zephir_check_call_status();
	_3 = zephir_fetch_nproperty_this(this_ptr, SL("unitOfWork"), PH_NOISY_CC);
	ZEPHIR_RETURN_CALL_METHOD(_3, "merge", NULL, document);
	zephir_check_call_status();
	RETURN_MM();

}

/**
 * Acquire a lock on the given document.
 *
 * @param object $document
 * @param int $lockMode
 * @param int $lockVersion
 * @throws \InvalidArgumentException
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, lock) {

	int ZEPHIR_LAST_CALL_STATUS;
	zval *document, *lockMode, *lockVersion = NULL, *_0, *_1, *_2;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 2, 1, &document, &lockMode, &lockVersion);

	if (!lockVersion) {
		lockVersion = ZEPHIR_GLOBAL(global_null);
	}


	if (!(Z_TYPE_P(document) == IS_OBJECT)) {
		ZEPHIR_INIT_VAR(_0);
		object_init_ex(_0, spl_ce_InvalidArgumentException);
		ZEPHIR_INIT_VAR(_1);
		zephir_gettype(_1, document TSRMLS_CC);
		ZEPHIR_CALL_METHOD(NULL, _0, "__construct", NULL, _1);
		zephir_check_call_status();
		zephir_throw_exception_debug(_0, "doctrine/odm/mongodb/documentmanager.zep", 509 TSRMLS_CC);
		ZEPHIR_MM_RESTORE();
		return;
	}
	_2 = zephir_fetch_nproperty_this(this_ptr, SL("unitOfWork"), PH_NOISY_CC);
	ZEPHIR_CALL_METHOD(NULL, _2, "lock", NULL, document, lockMode, lockVersion);
	zephir_check_call_status();
	ZEPHIR_MM_RESTORE();

}

/**
 * Releases a lock on the given document.
 *
 * @param object $document
 * @throws \InvalidArgumentException if the $document param is not an object
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, unlock) {

	int ZEPHIR_LAST_CALL_STATUS;
	zval *document, *_0, *_1, *_2;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 1, 0, &document);



	if (!(Z_TYPE_P(document) == IS_OBJECT)) {
		ZEPHIR_INIT_VAR(_0);
		object_init_ex(_0, spl_ce_InvalidArgumentException);
		ZEPHIR_INIT_VAR(_1);
		zephir_gettype(_1, document TSRMLS_CC);
		ZEPHIR_CALL_METHOD(NULL, _0, "__construct", NULL, _1);
		zephir_check_call_status();
		zephir_throw_exception_debug(_0, "doctrine/odm/mongodb/documentmanager.zep", 523 TSRMLS_CC);
		ZEPHIR_MM_RESTORE();
		return;
	}
	_2 = zephir_fetch_nproperty_this(this_ptr, SL("unitOfWork"), PH_NOISY_CC);
	ZEPHIR_CALL_METHOD(NULL, _2, "unlock", NULL, document);
	zephir_check_call_status();
	ZEPHIR_MM_RESTORE();

}

/**
 * Gets the repository for a document class.
 *
 * @param string $documentName  The name of the Document.
 * @return DocumentRepository  The repository.
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getRepository) {

	zend_class_entry *_4, *_6;
	zephir_nts_static zephir_fcall_cache_entry *_2 = NULL;
	int ZEPHIR_LAST_CALL_STATUS;
	zval *documentName, *newDocumentName, *repository, *metadata = NULL, *customRepositoryClassName = NULL, _0, *_1, *_3, *_5;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 1, 0, &documentName);



	ZEPHIR_INIT_VAR(newDocumentName);
	ZEPHIR_SINIT_VAR(_0);
	ZVAL_STRING(&_0, "\\", 0);
	zephir_fast_trim(newDocumentName, documentName, &_0, ZEPHIR_TRIM_LEFT TSRMLS_CC);
	ZEPHIR_OBS_VAR(repository);
	_1 = zephir_fetch_nproperty_this(this_ptr, SL("repositories"), PH_NOISY_CC);
	if (zephir_array_isset_fetch(&repository, _1, newDocumentName, 0 TSRMLS_CC)) {
		RETURN_CCTOR(repository);
	}
	ZEPHIR_CALL_METHOD(&metadata, this_ptr, "getclassmetadata", &_2, newDocumentName);
	zephir_check_call_status();
	ZEPHIR_OBS_VAR(_3);
	zephir_read_property(&_3, metadata, SL("customRepositoryClassName"), PH_NOISY_CC);
	ZEPHIR_CPY_WRT(customRepositoryClassName, _3);
	ZEPHIR_INIT_BNVAR(repository);
	if (Z_TYPE_P(customRepositoryClassName) != IS_NULL) {
		_4 = zend_fetch_class(Z_STRVAL_P(customRepositoryClassName), Z_STRLEN_P(customRepositoryClassName), ZEND_FETCH_CLASS_AUTO TSRMLS_CC);
		object_init_ex(repository, _4);
		if (zephir_has_constructor(repository TSRMLS_CC)) {
			_5 = zephir_fetch_nproperty_this(this_ptr, SL("unitOfWork"), PH_NOISY_CC);
			ZEPHIR_CALL_METHOD(NULL, repository, "__construct", NULL, this_ptr, _5, metadata);
			zephir_check_call_status();
		}
	} else {
		_6 = zend_fetch_class(SL("Doctrine\\ODM\\MongoDB\\DocumentRepository"), ZEND_FETCH_CLASS_AUTO TSRMLS_CC);
		object_init_ex(repository, _6);
		if (zephir_has_constructor(repository TSRMLS_CC)) {
			_5 = zephir_fetch_nproperty_this(this_ptr, SL("unitOfWork"), PH_NOISY_CC);
			ZEPHIR_CALL_METHOD(NULL, repository, "__construct", NULL, this_ptr, _5, metadata);
			zephir_check_call_status();
		}
	}
	zephir_update_property_array(this_ptr, SL("repositories"), documentName, repository TSRMLS_CC);
	RETURN_CCTOR(repository);

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
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, flush) {

	zephir_nts_static zephir_fcall_cache_entry *_4 = NULL;
	int ZEPHIR_LAST_CALL_STATUS;
	zend_bool _0, _1;
	zval *options = NULL;
	zval *document = NULL, *options_param = NULL, *_2, *_3, *_5;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 0, 2, &document, &options_param);

	if (!document) {
		document = ZEPHIR_GLOBAL(global_null);
	}
	if (!options_param) {
		ZEPHIR_INIT_VAR(options);
		array_init(options);
	} else {
		zephir_get_arrval(options, options_param);
	}


	_0 = Z_TYPE_P(document) != IS_NULL;
	if (_0) {
		_0 = !Z_TYPE_P(document) == IS_OBJECT;
	}
	_1 = _0;
	if (_1) {
		_1 = !Z_TYPE_P(document) == IS_ARRAY;
	}
	if (_1) {
		ZEPHIR_INIT_VAR(_2);
		object_init_ex(_2, spl_ce_InvalidArgumentException);
		ZEPHIR_INIT_VAR(_3);
		zephir_gettype(_3, document TSRMLS_CC);
		ZEPHIR_CALL_METHOD(NULL, _2, "__construct", NULL, _3);
		zephir_check_call_status();
		zephir_throw_exception_debug(_2, "doctrine/odm/mongodb/documentmanager.zep", 570 TSRMLS_CC);
		ZEPHIR_MM_RESTORE();
		return;
	}
	ZEPHIR_CALL_METHOD(NULL, this_ptr, "errorifclosed", &_4);
	zephir_check_call_status();
	_5 = zephir_fetch_nproperty_this(this_ptr, SL("unitOfWork"), PH_NOISY_CC);
	ZEPHIR_CALL_METHOD(NULL, _5, "commit", NULL, document, options);
	zephir_check_call_status();
	ZEPHIR_MM_RESTORE();

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
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getReference) {

	zval *_6;
	int ZEPHIR_LAST_CALL_STATUS;
	zval *documentName, *identifier, *classInstance = NULL, *document = NULL, *name, *_0, *_1, _2, *_3, *_4, *_5, *_7, *_8;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 2, 0, &documentName, &identifier);



	_0 = zephir_fetch_nproperty_this(this_ptr, SL("metadataFactory"), PH_NOISY_CC);
	ZEPHIR_INIT_VAR(_1);
	ZEPHIR_SINIT_VAR(_2);
	ZVAL_STRING(&_2, "\\", 0);
	zephir_fast_trim(_1, documentName, &_2, ZEPHIR_TRIM_LEFT TSRMLS_CC);
	ZEPHIR_CALL_METHOD(&classInstance, _0, "getmetadatafor", NULL, _1);
	zephir_check_call_status();
	_3 = zephir_fetch_nproperty_this(this_ptr, SL("unitOfWork"), PH_NOISY_CC);
	ZEPHIR_CALL_METHOD(&document, _3, "trygetbyid", NULL, identifier, classInstance);
	zephir_check_call_status();
	if (zephir_is_true(document)) {
		RETURN_CCTOR(document);
	}
	ZEPHIR_OBS_VAR(name);
	zephir_read_property(&name, classInstance, SL("identifier"), PH_NOISY_CC);
	_4 = zephir_fetch_nproperty_this(this_ptr, SL("proxyFactory"), PH_NOISY_CC);
	ZEPHIR_OBS_VAR(_5);
	zephir_read_property(&_5, classInstance, SL("name"), PH_NOISY_CC);
	ZEPHIR_INIT_VAR(_6);
	array_init_size(_6, 2);
	zephir_array_update_zval(&_6, name, &identifier, PH_COPY);
	ZEPHIR_CALL_METHOD(&document, _4, "getproxy", NULL, _5, _6);
	zephir_check_call_status();
	_7 = zephir_fetch_nproperty_this(this_ptr, SL("unitOfWork"), PH_NOISY_CC);
	ZEPHIR_INIT_VAR(_8);
	array_init(_8);
	ZEPHIR_CALL_METHOD(NULL, _7, "registermanaged", NULL, document, identifier, _8);
	zephir_check_call_status();
	RETURN_CCTOR(document);

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
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getPartialReference) {

	int ZEPHIR_LAST_CALL_STATUS;
	zval *documentName, *identifier, *classInstance = NULL, *document = NULL, *_0, *_1, _2, *_3, *_4, *_5;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 2, 0, &documentName, &identifier);



	_0 = zephir_fetch_nproperty_this(this_ptr, SL("metadataFactory"), PH_NOISY_CC);
	ZEPHIR_INIT_VAR(_1);
	ZEPHIR_SINIT_VAR(_2);
	ZVAL_STRING(&_2, "\\", 0);
	zephir_fast_trim(_1, documentName, &_2, ZEPHIR_TRIM_LEFT TSRMLS_CC);
	ZEPHIR_CALL_METHOD(&classInstance, _0, "getmetadatafor", NULL, _1);
	zephir_check_call_status();
	_3 = zephir_fetch_nproperty_this(this_ptr, SL("unitOfWork"), PH_NOISY_CC);
	ZEPHIR_CALL_METHOD(&document, _3, "trygetbyid", NULL, identifier, classInstance);
	zephir_check_call_status();
	if (zephir_is_true(document)) {
		RETURN_CCTOR(document);
	}
	ZEPHIR_CALL_METHOD(&document, classInstance, "newinstance",  NULL);
	zephir_check_call_status();
	ZEPHIR_CALL_METHOD(NULL, classInstance, "setidentifiervalue", NULL, document, identifier);
	zephir_check_call_status();
	_4 = zephir_fetch_nproperty_this(this_ptr, SL("unitOfWork"), PH_NOISY_CC);
	ZEPHIR_INIT_VAR(_5);
	array_init(_5);
	ZEPHIR_CALL_METHOD(NULL, _4, "registermanaged", NULL, document, identifier, _5);
	zephir_check_call_status();
	RETURN_CCTOR(document);

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
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, find) {

	zephir_nts_static zephir_fcall_cache_entry *_1 = NULL;
	int ZEPHIR_LAST_CALL_STATUS;
	zval *documentName, *identifier, *lockMode = NULL, *lockVersion = NULL, *_0 = NULL;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 2, 2, &documentName, &identifier, &lockMode, &lockVersion);

	if (!lockMode) {
		ZEPHIR_INIT_VAR(lockMode);
		ZVAL_LONG(lockMode, 0);
	}
	if (!lockVersion) {
		lockVersion = ZEPHIR_GLOBAL(global_null);
	}


	ZEPHIR_CALL_METHOD(&_0, this_ptr, "getrepository", &_1, documentName);
	zephir_check_call_status();
	ZEPHIR_RETURN_CALL_METHOD(_0, "find", NULL, identifier, lockMode, lockVersion);
	zephir_check_call_status();
	RETURN_MM();

}

/**
 * Clears the DocumentManager.
 *
 * All documents that are currently managed by this DocumentManager become
 * detached.
 *
 * @param string|null $documentName if given, only documents of this type will get detached
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, clear) {

	int ZEPHIR_LAST_CALL_STATUS;
	zval *documentName = NULL, *_0;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 0, 1, &documentName);

	if (!documentName) {
		documentName = ZEPHIR_GLOBAL(global_null);
	}


	_0 = zephir_fetch_nproperty_this(this_ptr, SL("unitOfWork"), PH_NOISY_CC);
	ZEPHIR_CALL_METHOD(NULL, _0, "clear", NULL, documentName);
	zephir_check_call_status();
	ZEPHIR_MM_RESTORE();

}

/**
 * Closes the DocumentManager. All documents that are currently managed
 * by this DocumentManager become detached. The DocumentManager may no longer
 * be used after it is closed.
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, close) {

	zephir_nts_static zephir_fcall_cache_entry *_0 = NULL;
	int ZEPHIR_LAST_CALL_STATUS;

	ZEPHIR_MM_GROW();

	ZEPHIR_CALL_METHOD(NULL, this_ptr, "clear", &_0);
	zephir_check_call_status();
	zephir_update_property_this(this_ptr, SL("closed"), (1) ? ZEPHIR_GLOBAL(global_true) : ZEPHIR_GLOBAL(global_false) TSRMLS_CC);
	ZEPHIR_MM_RESTORE();

}

/**
 * Determines whether a document instance is managed in this DocumentManager.
 *
 * @param object $document
 * @throws \InvalidArgumentException When the $document param is not an object
 * @return boolean TRUE if this DocumentManager currently manages the given document, FALSE otherwise.
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, contains) {

	zend_bool _4, _6;
	int ZEPHIR_LAST_CALL_STATUS;
	zval *document, *unitOfWork = NULL, *_0, *_1, *_2, *_3 = NULL, *_5 = NULL, *_7 = NULL;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 1, 0, &document);



	if (!(Z_TYPE_P(document) == IS_OBJECT)) {
		ZEPHIR_INIT_VAR(_0);
		object_init_ex(_0, spl_ce_InvalidArgumentException);
		ZEPHIR_INIT_VAR(_1);
		zephir_gettype(_1, document TSRMLS_CC);
		ZEPHIR_CALL_METHOD(NULL, _0, "__construct", NULL, _1);
		zephir_check_call_status();
		zephir_throw_exception_debug(_0, "doctrine/odm/mongodb/documentmanager.zep", 699 TSRMLS_CC);
		ZEPHIR_MM_RESTORE();
		return;
	}
	_2 = zephir_fetch_nproperty_this(this_ptr, SL("unitOfWork"), PH_NOISY_CC);
	ZEPHIR_CPY_WRT(unitOfWork, _2);
	ZEPHIR_CALL_METHOD(&_3, unitOfWork, "isscheduledforinsert", NULL, document);
	zephir_check_call_status();
	_4 = zephir_is_true(_3);
	if (!(_4)) {
		ZEPHIR_CALL_METHOD(&_5, unitOfWork, "isinidentitymap", NULL, document);
		zephir_check_call_status();
		_6 = zephir_is_true(_5);
		if (_6) {
			ZEPHIR_CALL_METHOD(&_7, unitOfWork, "isscheduledfordelete", NULL, document);
			zephir_check_call_status();
			_6 = zephir_is_true(_7);
		}
		_4 = _6;
	}
	RETURN_MM_BOOL(_4);

}

/**
 * Gets the Configuration used by the DocumentManager.
 *
 * @return Configuration
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getConfiguration) {


	RETURN_MEMBER(this_ptr, "config");

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
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, xcreateDBRef) {

	zval *referenceMapping = NULL;
	zval *document, *referenceMapping_param = NULL;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 1, 1, &document, &referenceMapping_param);

	if (!referenceMapping_param) {
	ZEPHIR_INIT_VAR(referenceMapping);
	ZVAL_NULL(referenceMapping);
	} else {
		zephir_get_arrval(referenceMapping, referenceMapping_param);
	}



}

/**
 * Throws an exception if the DocumentManager is closed or currently not active.
 *
 * @throws MongoDBException If the DocumentManager is closed.
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, errorIfClosed) {

	zval *_0;


	_0 = zephir_fetch_nproperty_this(this_ptr, SL("closed"), PH_NOISY_CC);
	if (zephir_is_true(_0)) {
		ZEPHIR_THROW_EXCEPTION_DEBUG_STRW(zend_exception_get_default(TSRMLS_C), "?", "doctrine/odm/mongodb/documentmanager.zep", 797);
		return;
	}

}

/**
 * Check if the Document manager is open or closed.
 *
 * @return bool
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, isOpen) {

	zval *_0;


	_0 = zephir_fetch_nproperty_this(this_ptr, SL("closed"), PH_NOISY_CC);
	RETURN_BOOL(!zephir_is_true(_0));

}

/**
 * Gets the filter collection.
 *
 * @return \Doctrine\ODM\MongoDB\Query\FilterCollection The active filter collection.
 */
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getFilterCollection) {

	int ZEPHIR_LAST_CALL_STATUS;
	zend_class_entry *_0;
	zval *filter;

	ZEPHIR_MM_GROW();

	ZEPHIR_OBS_VAR(filter);
	zephir_read_property_this(&filter, this_ptr, SL("filterCollection"), PH_NOISY_CC);
	if (Z_TYPE_P(filter) == IS_NULL) {
		ZEPHIR_INIT_BNVAR(filter);
		_0 = zend_fetch_class(SL("Doctrine\\ODM\\MongoDB\\Query\\FilterCollection"), ZEND_FETCH_CLASS_AUTO TSRMLS_CC);
		object_init_ex(filter, _0);
		if (zephir_has_constructor(filter TSRMLS_CC)) {
			ZEPHIR_CALL_METHOD(NULL, filter, "__construct", NULL, this_ptr);
			zephir_check_call_status();
		}
		zephir_update_property_this(this_ptr, SL("filterCollection"), filter TSRMLS_CC);
	}
	RETURN_CCTOR(filter);

}

