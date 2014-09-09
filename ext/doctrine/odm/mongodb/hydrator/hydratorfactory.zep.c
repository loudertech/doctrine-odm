
#ifdef HAVE_CONFIG_H
#include "../../../../ext_config.h"
#endif

#include <php.h>
#include "../../../../php_ext.h"
#include "../../../../ext.h"

#include <Zend/zend_operators.h>
#include <Zend/zend_exceptions.h>
#include <Zend/zend_interfaces.h>

#include "kernel/main.h"
#include "kernel/operators.h"
#include "kernel/exception.h"
#include "kernel/object.h"
#include "kernel/memory.h"
#include "kernel/array.h"
#include "kernel/concat.h"
#include "kernel/string.h"
#include "kernel/fcall.h"
#include "kernel/require.h"
#include "kernel/hash.h"


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
/**
 * The HydratorFactory class is responsible for instantiating a correct hydrator
 * type based on document's ClassMetadata
 *
 * @since       1.0
 * @author      Jonathan H. Wage <jonwage@gmail.com>
 */
ZEPHIR_INIT_CLASS(Doctrine_ODM_MongoDB_Hydrator_HydratorFactory) {

	ZEPHIR_REGISTER_CLASS(Doctrine\\ODM\\MongoDB\\Hydrator, HydratorFactory, doctrine, odm_mongodb_hydrator_hydratorfactory, doctrine_odm_mongodb_hydrator_hydratorfactory_method_entry, 0);

	/**
	 * The DocumentManager this factory is bound to.
	 *
	 * @var \Doctrine\ODM\MongoDB\DocumentManager
	 */
	zend_declare_property_null(doctrine_odm_mongodb_hydrator_hydratorfactory_ce, SL("dm"), ZEND_ACC_PUBLIC TSRMLS_CC);

	/**
	 * The UnitOfWork used to coordinate object-level transactions.
	 *
	 * @var \Doctrine\ODM\MongoDB\UnitOfWork
	 */
	zend_declare_property_null(doctrine_odm_mongodb_hydrator_hydratorfactory_ce, SL("unitOfWork"), ZEND_ACC_PUBLIC TSRMLS_CC);

	/**
	 * The EventManager associated with this Hydrator
	 *
	 * @var \Doctrine\Common\EventManager
	 */
	zend_declare_property_null(doctrine_odm_mongodb_hydrator_hydratorfactory_ce, SL("evm"), ZEND_ACC_PUBLIC TSRMLS_CC);

	/**
	 * Whether to automatically (re)generate hydrator classes.
	 *
	 * @var boolean
	 */
	zend_declare_property_null(doctrine_odm_mongodb_hydrator_hydratorfactory_ce, SL("autoGenerate"), ZEND_ACC_PUBLIC TSRMLS_CC);

	/**
	 * The namespace that contains all hydrator classes.
	 *
	 * @var string
	 */
	zend_declare_property_null(doctrine_odm_mongodb_hydrator_hydratorfactory_ce, SL("hydratorNamespace"), ZEND_ACC_PUBLIC TSRMLS_CC);

	/**
	 * The directory that contains all hydrator classes.
	 *
	 * @var string
	 */
	zend_declare_property_null(doctrine_odm_mongodb_hydrator_hydratorfactory_ce, SL("hydratorDir"), ZEND_ACC_PUBLIC TSRMLS_CC);

	/**
	 * Array of instantiated document hydrators.
	 *
	 * @var array
	 */
	zend_declare_property_null(doctrine_odm_mongodb_hydrator_hydratorfactory_ce, SL("hydrators"), ZEND_ACC_PUBLIC TSRMLS_CC);

	return SUCCESS;

}

/**
 * @param DocumentManager $dm
 * @param EventManager $evm
 * @param string $hydratorDir
 * @param string $hydratorNs
 * @param boolean $autoGenerate
 * @throws HydratorException
 */
PHP_METHOD(Doctrine_ODM_MongoDB_Hydrator_HydratorFactory, __construct) {

	zval *dm, *evm, *hydratorDir, *hydratorNs, *autoGenerate, *_0;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 5, 0, &dm, &evm, &hydratorDir, &hydratorNs, &autoGenerate);



	if (!(zephir_is_true(hydratorDir))) {
		ZEPHIR_THROW_EXCEPTION_DEBUG_STR(zend_exception_get_default(TSRMLS_C), "?", "doctrine/odm/mongodb/hydrator/hydratorfactory.zep", 102);
		return;
	}
	if (!(zephir_is_true(hydratorNs))) {
		ZEPHIR_THROW_EXCEPTION_DEBUG_STR(zend_exception_get_default(TSRMLS_C), "?", "doctrine/odm/mongodb/hydrator/hydratorfactory.zep", 106);
		return;
	}
	zephir_update_property_this(this_ptr, SL("dm"), dm TSRMLS_CC);
	zephir_update_property_this(this_ptr, SL("evm"), evm TSRMLS_CC);
	zephir_update_property_this(this_ptr, SL("hydratorDir"), hydratorDir TSRMLS_CC);
	zephir_update_property_this(this_ptr, SL("hydratorNamespace"), hydratorNs TSRMLS_CC);
	zephir_update_property_this(this_ptr, SL("autoGenerate"), autoGenerate TSRMLS_CC);
	ZEPHIR_INIT_VAR(_0);
	array_init(_0);
	zephir_update_property_this(this_ptr, SL("hydrators"), _0 TSRMLS_CC);
	ZEPHIR_MM_RESTORE();

}

/**
 * Sets the UnitOfWork instance.
 *
 * @param UnitOfWork $uow
 */
PHP_METHOD(Doctrine_ODM_MongoDB_Hydrator_HydratorFactory, setUnitOfWork) {

	zval *uow;

	zephir_fetch_params(0, 1, 0, &uow);



	zephir_update_property_this(this_ptr, SL("unitOfWork"), uow TSRMLS_CC);

}

/**
 * Gets the hydrator object for the given document class.
 *
 * @param string $className
 * @return \Doctrine\ODM\MongoDB\Hydrator\HydratorInterface $hydrator
 */
PHP_METHOD(Doctrine_ODM_MongoDB_Hydrator_HydratorFactory, getHydratorFor) {

	zend_class_entry *_8;
	int ZEPHIR_LAST_CALL_STATUS;
	zval *className, *hydrator, *hydratorClassName, *fileName, *fqn, *classInstance = NULL, *_0, *_1, _2, _3, *_4, *_5, *_6, *_7;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 1, 0, &className);



	ZEPHIR_OBS_VAR(hydrator);
	_0 = zephir_fetch_nproperty_this(this_ptr, SL("hydrators"), PH_NOISY_CC);
	if (zephir_array_isset_fetch(&hydrator, _0, className, 0 TSRMLS_CC)) {
		RETURN_CCTOR(hydrator);
	}
	ZEPHIR_INIT_VAR(_1);
	ZEPHIR_SINIT_VAR(_2);
	ZVAL_STRING(&_2, "\\", 0);
	ZEPHIR_SINIT_VAR(_3);
	ZVAL_STRING(&_3, "", 0);
	zephir_fast_str_replace(_1, &_2, &_3, className);
	ZEPHIR_INIT_VAR(hydratorClassName);
	ZEPHIR_CONCAT_VS(hydratorClassName, _1, "Hydrator");
	_4 = zephir_fetch_nproperty_this(this_ptr, SL("hydratorNamespace"), PH_NOISY_CC);
	ZEPHIR_INIT_VAR(fqn);
	ZEPHIR_CONCAT_VSV(fqn, _4, "\\", hydratorClassName);
	_5 = zephir_fetch_nproperty_this(this_ptr, SL("dm"), PH_NOISY_CC);
	ZEPHIR_CALL_METHOD(&classInstance, _5, "getclassmetadata", NULL, className);
	zephir_check_call_status();
	if (!(zephir_class_exists(fqn, zephir_is_true(ZEPHIR_GLOBAL(global_false))  TSRMLS_CC))) {
		_6 = zephir_fetch_nproperty_this(this_ptr, SL("hydratorDir"), PH_NOISY_CC);
		ZEPHIR_INIT_VAR(fileName);
		ZEPHIR_CONCAT_VSVS(fileName, _6, "/", hydratorClassName, ".php");
		_7 = zephir_fetch_nproperty_this(this_ptr, SL("autoGenerate"), PH_NOISY_CC);
		if (zephir_is_true(_7)) {
			ZEPHIR_CALL_METHOD(NULL, this_ptr, "generatehydratorclass", NULL, classInstance, hydratorClassName, fileName);
			zephir_check_call_status();
		}
		if (zephir_require_zval(fileName TSRMLS_CC) == FAILURE) {
			RETURN_MM_NULL();
		}
	}
	ZEPHIR_INIT_BNVAR(hydrator);
	_8 = zend_fetch_class(Z_STRVAL_P(fqn), Z_STRLEN_P(fqn), ZEND_FETCH_CLASS_AUTO TSRMLS_CC);
	object_init_ex(hydrator, _8);
	if (zephir_has_constructor(hydrator TSRMLS_CC)) {
		_6 = zephir_fetch_nproperty_this(this_ptr, SL("dm"), PH_NOISY_CC);
		_7 = zephir_fetch_nproperty_this(this_ptr, SL("unitOfWork"), PH_NOISY_CC);
		ZEPHIR_CALL_METHOD(NULL, hydrator, "__construct", NULL, _6, _7, classInstance);
		zephir_check_call_status();
	}
	zephir_update_property_array(this_ptr, SL("hydrators"), className, hydrator TSRMLS_CC);
	RETURN_CCTOR(hydrator);

}

/**
 * Generates hydrator classes for all given classes.
 *
 * @param array $classes The classes (ClassMetadata instances) for which to generate hydrators.
 * @param string $toDir The target directory of the hydrator classes. If not specified, the
 *                      directory configured on the Configuration of the DocumentManager used
 *                      by this factory is used.
 */
PHP_METHOD(Doctrine_ODM_MongoDB_Hydrator_HydratorFactory, generateHydratorClasses) {

	int ZEPHIR_LAST_CALL_STATUS;
	HashTable *_5;
	HashPosition _4;
	zval *classes_param = NULL, *toDir = NULL, *hydratorDir = NULL, *classInstance = NULL, *hydratorClassName = NULL, *hydratorFileName = NULL, *_0, *_1, _2, *_3, **_6, *_7 = NULL, *_8 = NULL, _9 = zval_used_for_init, _10 = zval_used_for_init;
	zval *classes = NULL;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 1, 1, &classes_param, &toDir);

	zephir_get_arrval(classes, classes_param);
	if (!toDir) {
		toDir = ZEPHIR_GLOBAL(global_null);
	}


	if (zephir_is_true(toDir)) {
		ZEPHIR_CPY_WRT(hydratorDir, toDir);
	} else {
		_0 = zephir_fetch_nproperty_this(this_ptr, SL("hydratorDir"), PH_NOISY_CC);
		ZEPHIR_CPY_WRT(hydratorDir, _0);
	}
	ZEPHIR_INIT_VAR(_1);
	ZEPHIR_SINIT_VAR(_2);
	ZVAL_STRING(&_2, "/", 0);
	zephir_fast_trim(_1, hydratorDir, &_2, ZEPHIR_TRIM_RIGHT TSRMLS_CC);
	ZEPHIR_INIT_VAR(_3);
	ZEPHIR_CONCAT_VS(_3, _1, "/");
	ZEPHIR_CPY_WRT(hydratorDir, _3);
	zephir_is_iterable(classes, &_5, &_4, 0, 0, "doctrine/odm/mongodb/hydrator/hydratorfactory.zep", 179);
	for (
	  ; zephir_hash_get_current_data_ex(_5, (void**) &_6, &_4) == SUCCESS
	  ; zephir_hash_move_forward_ex(_5, &_4)
	) {
		ZEPHIR_GET_HVALUE(classInstance, _6);
		ZEPHIR_INIT_NVAR(_7);
		ZEPHIR_OBS_NVAR(_8);
		zephir_read_property(&_8, classInstance, SL("name"), PH_NOISY_CC);
		ZEPHIR_SINIT_NVAR(_9);
		ZVAL_STRING(&_9, "\\", 0);
		ZEPHIR_SINIT_NVAR(_10);
		ZVAL_STRING(&_10, "", 0);
		zephir_fast_str_replace(_7, &_9, &_10, _8);
		ZEPHIR_INIT_NVAR(hydratorClassName);
		ZEPHIR_CONCAT_VS(hydratorClassName, _7, "Hydrator");
		ZEPHIR_INIT_NVAR(hydratorFileName);
		ZEPHIR_CONCAT_VVS(hydratorFileName, hydratorDir, hydratorClassName, ".php");
		ZEPHIR_CALL_METHOD(NULL, this_ptr, "generatehydratorclass", NULL, classInstance, hydratorClassName, hydratorFileName);
		zephir_check_call_status();
	}
	ZEPHIR_MM_RESTORE();

}

/**
 * Hydrate array of MongoDB document data into the given document object.
 *
 * @param object $document  The document object to hydrate the data into.
 * @param array $data The array of document data.
 * @param array $hints Any hints to account for during reconstitution/lookup of the document.
 * @return array $values The array of hydrated values.
 */
PHP_METHOD(Doctrine_ODM_MongoDB_Hydrator_HydratorFactory, hydrate) {

	HashTable *_4, *_7;
	HashPosition _3, _6;
	int ZEPHIR_LAST_CALL_STATUS;
	zval *hints = NULL;
	zval *document, *data = NULL, *hints_param = NULL, *metadata = NULL, *alsoLoadMethods = NULL, *method = NULL, *fieldNames = NULL, *fieldName = NULL, *_0, *_1, *_2 = NULL, **_5, **_8, *_9, *_10 = NULL, *_11 = NULL;

	ZEPHIR_MM_GROW();
	zephir_fetch_params(1, 2, 1, &document, &data, &hints_param);

	ZEPHIR_SEPARATE_PARAM(document);
	ZEPHIR_SEPARATE_PARAM(data);
	if (!hints_param) {
		ZEPHIR_INIT_VAR(hints);
		array_init(hints);
	} else {
		zephir_get_arrval(hints, hints_param);
	}


	_0 = zephir_fetch_nproperty_this(this_ptr, SL("dm"), PH_NOISY_CC);
	ZEPHIR_INIT_VAR(_1);
	zephir_get_class(_1, document, 0 TSRMLS_CC);
	ZEPHIR_CALL_METHOD(&metadata, _0, "getclassmetadata", NULL, _1);
	zephir_check_call_status();
	ZEPHIR_OBS_VAR(_2);
	zephir_read_property(&_2, metadata, SL("alsoLoadMethods"), PH_NOISY_CC);
	ZEPHIR_CPY_WRT(alsoLoadMethods, _2);
	if (!(ZEPHIR_IS_EMPTY(alsoLoadMethods))) {
		zephir_is_iterable(alsoLoadMethods, &_4, &_3, 0, 0, "doctrine/odm/mongodb/hydrator/hydratorfactory.zep", 217);
		for (
		  ; zephir_hash_get_current_data_ex(_4, (void**) &_5, &_3) == SUCCESS
		  ; zephir_hash_move_forward_ex(_4, &_3)
		) {
			ZEPHIR_GET_HMKEY(method, _4, _3);
			ZEPHIR_GET_HVALUE(fieldNames, _5);
			zephir_is_iterable(fieldNames, &_7, &_6, 0, 0, "doctrine/odm/mongodb/hydrator/hydratorfactory.zep", 216);
			for (
			  ; zephir_hash_get_current_data_ex(_7, (void**) &_8, &_6) == SUCCESS
			  ; zephir_hash_move_forward_ex(_7, &_6)
			) {
				ZEPHIR_GET_HVALUE(fieldName, _8);
				if (zephir_array_key_exists(data, fieldName TSRMLS_CC)) {
					zephir_array_fetch(&_9, data, fieldName, PH_NOISY | PH_READONLY, "doctrine/odm/mongodb/hydrator/hydratorfactory.zep", 212 TSRMLS_CC);
					ZEPHIR_CALL_METHOD(NULL, document, Z_STRVAL_P(method), NULL, _9);
					zephir_check_call_status();
					break;
				}
			}
		}
	}
	ZEPHIR_OBS_NVAR(_2);
	zephir_read_property(&_2, metadata, SL("name"), PH_NOISY_CC);
	ZEPHIR_CALL_METHOD(&_10, this_ptr, "gethydratorfor", NULL, _2);
	zephir_check_call_status();
	ZEPHIR_CALL_METHOD(&_11, _10, "hydrate", NULL, document, data, hints);
	zephir_check_call_status();
	ZEPHIR_CPY_WRT(data, _11);
	if (zephir_is_instance_of(document, SL("Doctrine\\ODM\\MongoDB\\Proxy\\Proxy") TSRMLS_CC)) {
		zephir_update_property_zval(document, SL("__isInitialized__"), (1) ? ZEPHIR_GLOBAL(global_true) : ZEPHIR_GLOBAL(global_false) TSRMLS_CC);
	}
	RETVAL_ZVAL(data, 1, 0);
	RETURN_MM();

}

