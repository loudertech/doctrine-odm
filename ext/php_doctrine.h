
/* This file was generated automatically by Zephir do not modify it! */

#ifndef PHP_DOCTRINE_H
#define PHP_DOCTRINE_H 1

#define ZEPHIR_RELEASE 1

#include "kernel/globals.h"

#define PHP_DOCTRINE_NAME        "doctrine"
#define PHP_DOCTRINE_VERSION     "0.0.1"
#define PHP_DOCTRINE_EXTNAME     "doctrine"
#define PHP_DOCTRINE_AUTHOR      ""
#define PHP_DOCTRINE_ZEPVERSION  "0.4.6a"
#define PHP_DOCTRINE_DESCRIPTION ""



ZEND_BEGIN_MODULE_GLOBALS(doctrine)

	/* Memory */
	zephir_memory_entry *start_memory; /**< The first preallocated frame */
	zephir_memory_entry *end_memory; /**< The last preallocate frame */
	zephir_memory_entry *active_memory; /**< The current memory frame */

	/* Virtual Symbol Tables */
	zephir_symbol_table *active_symbol_table;

	/** Function cache */
	HashTable *fcache;

	/* Max recursion control */
	unsigned int recursive_lock;

	/* Global constants */
	zval *global_true;
	zval *global_false;
	zval *global_null;
	
ZEND_END_MODULE_GLOBALS(doctrine)

#ifdef ZTS
#include "TSRM.h"
#endif

ZEND_EXTERN_MODULE_GLOBALS(doctrine)

#ifdef ZTS
	#define ZEPHIR_GLOBAL(v) TSRMG(doctrine_globals_id, zend_doctrine_globals *, v)
#else
	#define ZEPHIR_GLOBAL(v) (doctrine_globals.v)
#endif

#ifdef ZTS
	#define ZEPHIR_VGLOBAL ((zend_doctrine_globals *) (*((void ***) tsrm_ls))[TSRM_UNSHUFFLE_RSRC_ID(doctrine_globals_id)])
#else
	#define ZEPHIR_VGLOBAL &(doctrine_globals)
#endif

#define zephir_globals_def doctrine_globals
#define zend_zephir_globals_def zend_doctrine_globals

extern zend_module_entry doctrine_module_entry;
#define phpext_doctrine_ptr &doctrine_module_entry

#endif
