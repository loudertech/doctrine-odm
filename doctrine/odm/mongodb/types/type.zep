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

namespace Doctrine\ODM\MongoDB\Types;

use Doctrine\ODM\MongoDB\Mapping\MappingException;

/**
 * The Type interface.
 *
 * @since       1.0
 * @author      Jonathan H. Wage <jonwage@gmail.com>
 * @author      Roman Borschel <roman@code-factory.org>
 */
abstract class Type
{
    const ID = "id";
    const INTID = "int_id";
    const CUSTOMID = "custom_id";
    const BOOLEAN1 = "boolean";
    const INTEGER = "int";
    const FLOAT1 = "float";
    const STRING1 = "string";
    const DATE = "date";
    const KEY = "key";
    const TIMESTAMP = "timestamp";
    const BINDATA = "bin";
    const BINDATAFUNC = "bin_func";
    const BINDATABYTEARRAY = "bin_bytearray";
    const BINDATAUUID = "bin_uuid";
    const BINDATAMD5 = "bin_md5";
    const BINDATACUSTOM = "bin_custom";
    const FILE = "file";
    const HASH = "hash";
    const COLLECTION = "collection";
    const INCREMENT = "increment";
    const OBJECTID = "object_id";
    const RAW = "raw";


    const MAPPINGEXCEPTION = "MappingException";

    /** 
    * Map of already instantiated type objects. One instance per type (flyweight). 
    */
    private static typeObjects;

    /** 
    * The map of supported doctrine mapping typ
    */
    protected static typesMap = null;

    /* Prevent instantiation and force use of the factory method. */
    final protected function __construct() {}

    public static function init() 
    {
        if self::typesMap == null {
            let self::typesMap = [
                "id" : "Doctrine\\ODM\\MongoDB\\Types\\IdType",
                "int_id" : "Doctrine\\ODM\\MongoDB\\Types\\IntIdType",
                "custom_id" : "Doctrine\\ODM\\MongoDB\\Types\\CustomIdType",
                "boolean" : "Doctrine\\ODM\\MongoDB\\Types\\BooleanType",
                "int" : "Doctrine\\ODM\\MongoDB\\Types\\IntType",
                "float" : "Doctrine\\ODM\\MongoDB\\Types\\FloatType",
                "string" : "Doctrine\\ODM\\MongoDB\\Types\\StringType",
                "date" : "Doctrine\\ODM\\MongoDB\\Types\\DateType",
                "key" : "Doctrine\\ODM\\MongoDB\\Types\\KeyType",
                "timestamp" : "Doctrine\\ODM\\MongoDB\\Types\\TimestampType",
                "bin" : "Doctrine\\ODM\\MongoDB\\Types\\BinDataType",
                "bin" : "Doctrine\\ODM\\MongoDB\\Types\\BinDataFuncType",
                "bin_bytearray" : "Doctrine\\ODM\\MongoDB\\Types\\BinDataByteArrayType",
                "bin_uuid" : "Doctrine\\ODM\\MongoDB\\Types\\BinDataUUIDType",
                "bin_md5" : "Doctrine\\ODM\\MongoDB\\Types\\BinDataMD5Type",
                "bin_custom" : "Doctrine\\ODM\\MongoDB\\Types\\BinDataCustomType",
                "file" : "Doctrine\\ODM\\MongoDB\\Types\\FileType",
                "hash" : "Doctrine\\ODM\\MongoDB\\Types\\HashType",
                "collection" : "Doctrine\\ODM\\MongoDB\\Types\\CollectionType",
                "increment" : "Doctrine\\ODM\\MongoDB\\Types\\IncrementType",
                "object_id" : "Doctrine\\ODM\\MongoDB\\Types\\ObjectIdType",
                "raw" : "Doctrine\\ODM\\MongoDB\\Types\\RawType"
            ];
        }
        return self::typesMap;
    }

    /**
     * Converts a value from its PHP representation to its database representation
     * of this type.
     *
     * @param mixed value The value to convert.
     * @return mixed The database representation of the value.
     */
    public function convertToDatabaseValue(value)
    {
        return value;
    }

    /**
     * Converts a value from its database representation to its PHP representation
     * of this type.
     *
     * @param mixed value The value to convert.
     * @return mixed The PHP representation of the value.
     */
    public function convertToPHPValue(value)
    {
        return value;
    }

    public function closureToMongo()
    {
        return "return = value;";
    }

    public function closureToPHP()
    {
        return "return = value;";
    }

    /**
     * Register a new type in the type map.
     *
     * @param string name The name of the type.
     * @param string class The class name.
     */
    public static function registerType(name, class1)
    {
        let self::typesMap[name] = class1;
    }

    /**
     * Get a Type instance.
     *
     * @param string type The type name.
     * @return \Doctrine\ODM\MongoDB\Types\Type type
     * @throws \InvalidArgumentException
     */
    public static function getType(type)
    {
        var className;
        
        if self::typesMap == null {
            let self::typesMap = [
                "id" : "Doctrine\\ODM\\MongoDB\\Types\\IdType",
                "int_id" : "Doctrine\\ODM\\MongoDB\\Types\\IntIdType",
                "custom_id" : "Doctrine\\ODM\\MongoDB\\Types\\CustomIdType",
                "boolean" : "Doctrine\\ODM\\MongoDB\\Types\\BooleanType",
                "int" : "Doctrine\\ODM\\MongoDB\\Types\\IntType",
                "float" : "Doctrine\\ODM\\MongoDB\\Types\\FloatType",
                "string" : "Doctrine\\ODM\\MongoDB\\Types\\StringType",
                "date" : "Doctrine\\ODM\\MongoDB\\Types\\DateType",
                "key" : "Doctrine\\ODM\\MongoDB\\Types\\KeyType",
                "timestamp" : "Doctrine\\ODM\\MongoDB\\Types\\TimestampType",
                "bin" : "Doctrine\\ODM\\MongoDB\\Types\\BinDataType",
                "bin" : "Doctrine\\ODM\\MongoDB\\Types\\BinDataFuncType",
                "bin_bytearray" : "Doctrine\\ODM\\MongoDB\\Types\\BinDataByteArrayType",
                "bin_uuid" : "Doctrine\\ODM\\MongoDB\\Types\\BinDataUUIDType",
                "bin_md5" : "Doctrine\\ODM\\MongoDB\\Types\\BinDataMD5Type",
                "bin_custom" : "Doctrine\\ODM\\MongoDB\\Types\\BinDataCustomType",
                "file" : "Doctrine\\ODM\\MongoDB\\Types\\FileType",
                "hash" : "Doctrine\\ODM\\MongoDB\\Types\\HashType",
                "collection" : "Doctrine\\ODM\\MongoDB\\Types\\CollectionType",
                "increment" : "Doctrine\\ODM\\MongoDB\\Types\\IncrementType",
                "object_id" : "Doctrine\\ODM\\MongoDB\\Types\\ObjectIdType",
                "raw" : "Doctrine\\ODM\\MongoDB\\Types\\RawType"
            ];
        }

        if !isset self::typesMap[type] {
            throw new \InvalidArgumentException(sprintf("Invalid type specified '%s'.", type));
        }
        if !isset self::typeObjects[type] {
            let className = self::typesMap[type];
            let self::typeObjects[type] = new {className}();
        }
        return self::typeObjects[type];
    }

    /**
     * Get a Type instance based on the type of the passed php variable.
     *
     * @param mixed variable
     * @return \Doctrine\ODM\MongoDB\Types\Type type
     * @throws \InvalidArgumentException
     */
    public static function getTypeFromPHPVariable(variable)
    {
        var type;

        if typeof variable == "object" {
            if (variable instanceof \DateTime) {
                return self::getType("date");
            } else {
                if (variable instanceof \MongoId) {
                    return self::getType("id");
                }
            }
        } else {
            let type = gettype(variable);
            switch type {
                case "integer":
                    return self::getType("int");
                    break;
            }
        }
        return null;
    }

    public static function convertPHPToDatabaseValue(value)
    {
        var type;

        let type = self::getTypeFromPHPVariable(value);
        if type !== null {
            return type->convertToDatabaseValue(value);
        }
        return value;
    }

    /**
     * Adds a custom type to the type map.
     *
     * @static
     * @param string name Name of the type. This should correspond to what getName() returns.
     * @param string className The class name of the custom type.
     * @throws MappingException
     */
    public static function addType(name, className)
    {
        var x;
        if isset self::typesMap[name] == true {
            let x = MAPPINGEXCEPTION;
            throw {x}::typeExists(name);
        }

        let self::typesMap[name] = className;
    }

    /**
     * Checks if exists support for a type.
     *
     * @static
     * @param string name Name of the type
     * @return boolean TRUE if type is supported; FALSE otherwise
     */
    public static function hasType(name)
    {
        return isset(self::typesMap[name]);
    }

    /**
     * Overrides an already defined type to use a different implementation.
     *
     * @static
     * @param string name
     * @param string className
     * @throws MappingException
     */
    public static function overrideType(name, className)
    {
        var x;
        if ( ! isset(self::typesMap[name])) {
            let x = MAPPINGEXCEPTION;
            throw {x}::typeNotFound(name);
        }

        let self::typesMap[name] = className;
    }

    /**
     * Get the types array map which holds all registered types and the corresponding
     * type class
     *
     * @return array typesMap
     */
    public static function getTypesMap()
    {
        return self::typesMap;
    }

    public function __toString()
    {
        var e;
        let e = explode("\\", get_class(this));
        return str_replace("Type", "", end(e));
    }
}
