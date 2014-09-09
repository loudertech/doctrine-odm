
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
 * Contains all MongoDB ODM LockModes
 *
 * @since       1.0
 * @author      Benjamin Eberlei <kontakt@beberlei.de>
 * @author      Roman Borschel <roman@code-factory.org>
 * @author      Jonathan H. Wage <jonwage@gmail.com>
 */
ZEPHIR_INIT_CLASS(Doctrine_ODM_MongoDB_LockMode) {

	ZEPHIR_REGISTER_CLASS(Doctrine\\ODM\\MongoDB, LockMode, doctrine, odm_mongodb_lockmode, NULL, 0);

	zend_declare_class_constant_long(doctrine_odm_mongodb_lockmode_ce, SL("NONE"), 0 TSRMLS_CC);

	zend_declare_class_constant_long(doctrine_odm_mongodb_lockmode_ce, SL("OPTIMISTIC"), 1 TSRMLS_CC);

	zend_declare_class_constant_long(doctrine_odm_mongodb_lockmode_ce, SL("PESSIMISTIC_READ"), 2 TSRMLS_CC);

	zend_declare_class_constant_long(doctrine_odm_mongodb_lockmode_ce, SL("PESSIMISTIC_WRITE"), 4 TSRMLS_CC);

	return SUCCESS;

}

