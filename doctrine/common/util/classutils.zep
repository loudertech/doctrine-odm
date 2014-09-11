
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

namespace Doctrine\Common\Util;

use Doctrine\Common\Persistence\Proxy;

/**
 * Class and reflection related functionality for objects that
 * might or not be proxy objects at the moment.
 *
 * @author Benjamin Eberlei <kontakt@beberlei.de>
 * @author Johannes Schmitt <schmittjoh@gmail.com>
 */
class ClassUtils
{
    /**
     * Gets the real class name of a class name that could be a proxy.
     *
     * @param string $class
     *
     * @return string
     */
    public static final function getRealClass(className)
    {
        var pos;

        let pos = strrpos(className, "\\" . Proxy::MARKER . "\\");
        if pos === false {
            return className;
        }

        return substr(className, pos + Proxy::MARKER_LENGTH + 2);
    }

    /**
     * Gets the real class name of an object (even if its a proxy).
     *
     * @param object $object
     *
     * @return string
     */
    public static final function getClass(objectInstance)
    {
        return self::getRealClass(get_class(objectInstance));
    }

    /**
     * Gets the real parent class name of a class or object.
     *
     * @param string $className
     *
     * @return string
     */
    public static final function getParentClass(className)
    {
        return get_parent_class(self::getRealClass(className));
    }

    /**
     * Creates a new reflection class.
     *
     * @param string $class
     *
     * @return \ReflectionClass
     */
    public static final function newReflectionClass(className)
    {
        return new \ReflectionClass(self::getRealClass(className));
    }

    /**
     * Creates a new reflection object.
     *
     * @param object $object
     *
     * @return \ReflectionObject
     */
    public static final function newReflectionObject(objectInstance)
    {
        return self::newReflectionClass(self::getClass(objectInstance));
    }

    /**
     * Given a class name and a proxy namespace returns the proxy name.
     *
     * @param string $className
     * @param string $proxyNamespace
     *
     * @return string
     */
    public static final function generateProxyClassName(className, proxyNamespace)
    {
        return rtrim(proxyNamespace, "\\") . "\\" . Proxy::MARKER . "\\" . ltrim(className, "\\");
    }
}
