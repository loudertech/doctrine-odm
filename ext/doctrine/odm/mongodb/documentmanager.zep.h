
extern zend_class_entry *doctrine_odm_mongodb_documentmanager_ce;

ZEPHIR_INIT_CLASS(Doctrine_ODM_MongoDB_DocumentManager);

PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, __construct);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getProxyFactory);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, create);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getEventManager);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getConnection);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getMetadataFactory);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, initializeObject);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getUnitOfWork);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getHydratorFactory);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getSchemaManager);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getClassMetadata);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getDocumentDatabase);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getDocumentDatabases);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getDocumentCollection);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getDocumentCollections);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, createQueryBuilder);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, persist);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, remove);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, refresh);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, detach);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, merge);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, lock);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, unlock);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getRepository);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, flush);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getReference);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getPartialReference);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, find);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, clear);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, close);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, contains);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getConfiguration);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, xcreateDBRef);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, errorIfClosed);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, isOpen);
PHP_METHOD(Doctrine_ODM_MongoDB_DocumentManager, getFilterCollection);

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager___construct, 0, 0, 3)
	ZEND_ARG_INFO(0, conn)
	ZEND_ARG_INFO(0, config)
	ZEND_ARG_INFO(0, eventManager)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_create, 0, 0, 0)
	ZEND_ARG_INFO(0, conn)
	ZEND_ARG_INFO(0, config)
	ZEND_ARG_INFO(0, eventManager)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_initializeobject, 0, 0, 1)
	ZEND_ARG_INFO(0, obj)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_getclassmetadata, 0, 0, 1)
	ZEND_ARG_INFO(0, className)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_getdocumentdatabase, 0, 0, 1)
	ZEND_ARG_INFO(0, className)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_getdocumentcollection, 0, 0, 1)
	ZEND_ARG_INFO(0, className)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_createquerybuilder, 0, 0, 0)
	ZEND_ARG_INFO(0, documentName)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_persist, 0, 0, 1)
	ZEND_ARG_INFO(0, document)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_remove, 0, 0, 1)
	ZEND_ARG_INFO(0, document)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_refresh, 0, 0, 1)
	ZEND_ARG_INFO(0, document)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_detach, 0, 0, 1)
	ZEND_ARG_INFO(0, document)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_merge, 0, 0, 1)
	ZEND_ARG_INFO(0, document)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_lock, 0, 0, 2)
	ZEND_ARG_INFO(0, document)
	ZEND_ARG_INFO(0, lockMode)
	ZEND_ARG_INFO(0, lockVersion)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_unlock, 0, 0, 1)
	ZEND_ARG_INFO(0, document)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_getrepository, 0, 0, 1)
	ZEND_ARG_INFO(0, documentName)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_flush, 0, 0, 0)
	ZEND_ARG_INFO(0, document)
	ZEND_ARG_ARRAY_INFO(0, options, 1)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_getreference, 0, 0, 2)
	ZEND_ARG_INFO(0, documentName)
	ZEND_ARG_INFO(0, identifier)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_getpartialreference, 0, 0, 2)
	ZEND_ARG_INFO(0, documentName)
	ZEND_ARG_INFO(0, identifier)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_find, 0, 0, 2)
	ZEND_ARG_INFO(0, documentName)
	ZEND_ARG_INFO(0, identifier)
	ZEND_ARG_INFO(0, lockMode)
	ZEND_ARG_INFO(0, lockVersion)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_clear, 0, 0, 0)
	ZEND_ARG_INFO(0, documentName)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_contains, 0, 0, 1)
	ZEND_ARG_INFO(0, document)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_documentmanager_xcreatedbref, 0, 0, 1)
	ZEND_ARG_INFO(0, document)
	ZEND_ARG_ARRAY_INFO(0, referenceMapping, 1)
ZEND_END_ARG_INFO()

ZEPHIR_INIT_FUNCS(doctrine_odm_mongodb_documentmanager_method_entry) {
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, __construct, arginfo_doctrine_odm_mongodb_documentmanager___construct, ZEND_ACC_PROTECTED|ZEND_ACC_CTOR)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, getProxyFactory, NULL, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, create, arginfo_doctrine_odm_mongodb_documentmanager_create, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL|ZEND_ACC_STATIC)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, getEventManager, NULL, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, getConnection, NULL, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, getMetadataFactory, NULL, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, initializeObject, arginfo_doctrine_odm_mongodb_documentmanager_initializeobject, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, getUnitOfWork, NULL, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, getHydratorFactory, NULL, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, getSchemaManager, NULL, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, getClassMetadata, arginfo_doctrine_odm_mongodb_documentmanager_getclassmetadata, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, getDocumentDatabase, arginfo_doctrine_odm_mongodb_documentmanager_getdocumentdatabase, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, getDocumentDatabases, NULL, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, getDocumentCollection, arginfo_doctrine_odm_mongodb_documentmanager_getdocumentcollection, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, getDocumentCollections, NULL, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, createQueryBuilder, arginfo_doctrine_odm_mongodb_documentmanager_createquerybuilder, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, persist, arginfo_doctrine_odm_mongodb_documentmanager_persist, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, remove, arginfo_doctrine_odm_mongodb_documentmanager_remove, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, refresh, arginfo_doctrine_odm_mongodb_documentmanager_refresh, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, detach, arginfo_doctrine_odm_mongodb_documentmanager_detach, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, merge, arginfo_doctrine_odm_mongodb_documentmanager_merge, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, lock, arginfo_doctrine_odm_mongodb_documentmanager_lock, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, unlock, arginfo_doctrine_odm_mongodb_documentmanager_unlock, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, getRepository, arginfo_doctrine_odm_mongodb_documentmanager_getrepository, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, flush, arginfo_doctrine_odm_mongodb_documentmanager_flush, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, getReference, arginfo_doctrine_odm_mongodb_documentmanager_getreference, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, getPartialReference, arginfo_doctrine_odm_mongodb_documentmanager_getpartialreference, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, find, arginfo_doctrine_odm_mongodb_documentmanager_find, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, clear, arginfo_doctrine_odm_mongodb_documentmanager_clear, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, close, NULL, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, contains, arginfo_doctrine_odm_mongodb_documentmanager_contains, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, getConfiguration, NULL, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, xcreateDBRef, arginfo_doctrine_odm_mongodb_documentmanager_xcreatedbref, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, errorIfClosed, NULL, ZEND_ACC_PRIVATE)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, isOpen, NULL, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	PHP_ME(Doctrine_ODM_MongoDB_DocumentManager, getFilterCollection, NULL, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
  PHP_FE_END
};
