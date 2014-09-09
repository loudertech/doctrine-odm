
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
 * Container for all ODM events.
 *
 * This class cannot be instantiated.
 *
 * @since       1.0
 * @author      Jonathan H. Wage <jonwage@gmail.com>
 * @author      Roman Borschel <roman@code-factory.org>
 */
ZEPHIR_INIT_CLASS(Doctrine_ODM_MongoDB_Events) {

	ZEPHIR_REGISTER_CLASS(Doctrine\\ODM\\MongoDB, Events, doctrine, odm_mongodb_events, NULL, 0);

	/**
	 * The preRemove event occurs for a given document before the respective
	 * DocumentManager remove operation for that document is executed.
	 *
	 * This is a document lifecycle event.
	 *
	 * @var string
	 */
	zend_declare_class_constant_string(doctrine_odm_mongodb_events_ce, SL("preRemove"), "preRemove" TSRMLS_CC);

	/**
	 * The postRemove event occurs for a document after the document has
	 * been deleted. It will be invoked after the database delete operations.
	 *
	 * This is a document lifecycle event.
	 *
	 * @var string
	 */
	zend_declare_class_constant_string(doctrine_odm_mongodb_events_ce, SL("postRemove"), "postRemove" TSRMLS_CC);

	/**
	 * The prePersist event occurs for a given document before the respective
	 * DocumentManager persist operation for that document is executed.
	 *
	 * This is a document lifecycle event.
	 *
	 * @var string
	 */
	zend_declare_class_constant_string(doctrine_odm_mongodb_events_ce, SL("prePersist"), "prePersist" TSRMLS_CC);

	/**
	 * The postPersist event occurs for a document after the document has
	 * been made persistent. It will be invoked after the database insert operations.
	 * Generated primary key values are available in the postPersist event.
	 *
	 * This is a document lifecycle event.
	 *
	 * @var string
	 */
	zend_declare_class_constant_string(doctrine_odm_mongodb_events_ce, SL("postPersist"), "postPersist" TSRMLS_CC);

	/**
	 * The preUpdate event occurs before the database update operations to
	 * document data.
	 *
	 * This is a document lifecycle event.
	 *
	 * @var string
	 */
	zend_declare_class_constant_string(doctrine_odm_mongodb_events_ce, SL("preUpdate"), "preUpdate" TSRMLS_CC);

	/**
	 * The postUpdate event occurs after the database update operations to
	 * document data.
	 *
	 * This is a document lifecycle event.
	 *
	 * @var string
	 */
	zend_declare_class_constant_string(doctrine_odm_mongodb_events_ce, SL("postUpdate"), "postUpdate" TSRMLS_CC);

	/**
	 * The preLoad event occurs for a document before the document has been loaded
	 * into the current DocumentManager from the database or before the refresh operation
	 * has been applied to it.
	 *
	 * This is a document lifecycle event.
	 *
	 * @var string
	 */
	zend_declare_class_constant_string(doctrine_odm_mongodb_events_ce, SL("preLoad"), "preLoad" TSRMLS_CC);

	/**
	 * The postLoad event occurs for a document after the document has been loaded
	 * into the current DocumentManager from the database or after the refresh operation
	 * has been applied to it.
	 *
	 * Note that the postLoad event occurs for a document before any associations have been
	 * initialized. Therefore it is not safe to access associations in a postLoad callback
	 * or event handler.
	 *
	 * This is a document lifecycle event.
	 *
	 * @var string
	 */
	zend_declare_class_constant_string(doctrine_odm_mongodb_events_ce, SL("postLoad"), "postLoad" TSRMLS_CC);

	/**
	 * The loadClassMetadata event occurs after the mapping metadata for a class
	 * has been loaded from a mapping source (annotations/xml/yaml).
	 *
	 * @var string
	 */
	zend_declare_class_constant_string(doctrine_odm_mongodb_events_ce, SL("loadClassMetadata"), "loadClassMetadata" TSRMLS_CC);

	/**
	 * The preFlush event occurs when the DocumentManager#flush() operation is invoked,
	 * but before any changes to managed documents have been calculated. This event is
	 * always raised right after DocumentManager#flush() call.
	 */
	zend_declare_class_constant_string(doctrine_odm_mongodb_events_ce, SL("preFlush"), "preFlush" TSRMLS_CC);

	/**
	 * The onFlush event occurs when the DocumentManager#flush() operation is invoked,
	 * after any changes to managed documents have been determined but before any
	 * actual database operations are executed. The event is only raised if there is
	 * actually something to do for the underlying UnitOfWork. If nothing needs to be done,
	 * the onFlush event is not raised.
	 *
	 * @var string
	 */
	zend_declare_class_constant_string(doctrine_odm_mongodb_events_ce, SL("onFlush"), "onFlush" TSRMLS_CC);

	/**
	 * The postFlush event occurs when the DocumentManager#flush() operation is invoked and
	 * after all actual database operations are executed successfully. The event is only raised if there is
	 * actually something to do for the underlying UnitOfWork. If nothing needs to be done,
	 * the postFlush event is not raised. The event won"t be raised if an error occurs during the
	 * flush operation.
	 *
	 * @var string
	 */
	zend_declare_class_constant_string(doctrine_odm_mongodb_events_ce, SL("postFlush"), "postFlush" TSRMLS_CC);

	/**
	 * The onClear event occurs when the DocumentManager#clear() operation is invoked,
	 * after all references to documents have been removed from the unit of work.
	 *
	 * @var string
	 */
	zend_declare_class_constant_string(doctrine_odm_mongodb_events_ce, SL("onClear"), "onClear" TSRMLS_CC);

	return SUCCESS;

}

