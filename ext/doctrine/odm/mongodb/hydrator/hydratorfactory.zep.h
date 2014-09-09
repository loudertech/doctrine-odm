
extern zend_class_entry *doctrine_odm_mongodb_hydrator_hydratorfactory_ce;

ZEPHIR_INIT_CLASS(Doctrine_ODM_MongoDB_Hydrator_HydratorFactory);

PHP_METHOD(Doctrine_ODM_MongoDB_Hydrator_HydratorFactory, __construct);
PHP_METHOD(Doctrine_ODM_MongoDB_Hydrator_HydratorFactory, setUnitOfWork);
PHP_METHOD(Doctrine_ODM_MongoDB_Hydrator_HydratorFactory, getHydratorFor);
PHP_METHOD(Doctrine_ODM_MongoDB_Hydrator_HydratorFactory, generateHydratorClasses);
PHP_METHOD(Doctrine_ODM_MongoDB_Hydrator_HydratorFactory, hydrate);

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_hydrator_hydratorfactory___construct, 0, 0, 5)
	ZEND_ARG_INFO(0, dm)
	ZEND_ARG_INFO(0, evm)
	ZEND_ARG_INFO(0, hydratorDir)
	ZEND_ARG_INFO(0, hydratorNs)
	ZEND_ARG_INFO(0, autoGenerate)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_hydrator_hydratorfactory_setunitofwork, 0, 0, 1)
	ZEND_ARG_INFO(0, uow)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_hydrator_hydratorfactory_gethydratorfor, 0, 0, 1)
	ZEND_ARG_INFO(0, className)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_hydrator_hydratorfactory_generatehydratorclasses, 0, 0, 1)
	ZEND_ARG_ARRAY_INFO(0, classes, 0)
	ZEND_ARG_INFO(0, toDir)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_doctrine_odm_mongodb_hydrator_hydratorfactory_hydrate, 0, 0, 2)
	ZEND_ARG_INFO(0, document)
	ZEND_ARG_INFO(0, data)
	ZEND_ARG_ARRAY_INFO(0, hints, 1)
ZEND_END_ARG_INFO()

ZEPHIR_INIT_FUNCS(doctrine_odm_mongodb_hydrator_hydratorfactory_method_entry) {
	PHP_ME(Doctrine_ODM_MongoDB_Hydrator_HydratorFactory, __construct, arginfo_doctrine_odm_mongodb_hydrator_hydratorfactory___construct, ZEND_ACC_PUBLIC|ZEND_ACC_CTOR)
	PHP_ME(Doctrine_ODM_MongoDB_Hydrator_HydratorFactory, setUnitOfWork, arginfo_doctrine_odm_mongodb_hydrator_hydratorfactory_setunitofwork, ZEND_ACC_PUBLIC)
	PHP_ME(Doctrine_ODM_MongoDB_Hydrator_HydratorFactory, getHydratorFor, arginfo_doctrine_odm_mongodb_hydrator_hydratorfactory_gethydratorfor, ZEND_ACC_PUBLIC)
	PHP_ME(Doctrine_ODM_MongoDB_Hydrator_HydratorFactory, generateHydratorClasses, arginfo_doctrine_odm_mongodb_hydrator_hydratorfactory_generatehydratorclasses, ZEND_ACC_PUBLIC)
	PHP_ME(Doctrine_ODM_MongoDB_Hydrator_HydratorFactory, hydrate, arginfo_doctrine_odm_mongodb_hydrator_hydratorfactory_hydrate, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
  PHP_FE_END
};
