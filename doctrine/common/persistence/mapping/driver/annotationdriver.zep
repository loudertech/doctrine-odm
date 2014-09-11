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

namespace Doctrine\Common\Persistence\Mapping\Driver;

use Doctrine\Common\Annotations\AnnotationReader;
use Doctrine\Common\Annotations\AnnotationRegistry;
use Doctrine\Common\Persistence\Mapping\MappingException;

/**
 * The AnnotationDriver reads the mapping metadata from docblock annotations.
 *
 * @since  2.2
 * @author Benjamin Eberlei <kontakt@beberlei.de>
 * @author Guilherme Blanco <guilhermeblanco@hotmail.com>
 * @author Jonathan H. Wage <jonwage@gmail.com>
 * @author Roman Borschel <roman@code-factory.org>
 */
abstract class AnnotationDriver implements MappingDriver
{
    /**
     * The AnnotationReader.
     *
     * @var AnnotationReader
     */
    protected reader;

    /**
     * The paths where to look for mapping files.
     *
     * @var array
     */
    protected paths = [];

    /**
     * The paths excluded from path where to look for mapping files.
     *
     * @var array
     */
    protected excludePaths = [];

    /**
     * The file extension of mapping documents.
     *
     * @var string
     */
    protected fileExtension = ".php";

    /**
     * Cache for AnnotationDriver#getAllClassNames().
     *
     * @var array|null
     */
    protected classNames;

    /**
     * Name of the entity annotations as keys.
     *
     * @var array
     */
    protected entityAnnotationClasses = [];

    /**
     * Initializes a new AnnotationDriver that uses the given AnnotationReader for reading
     * docblock annotations.
     *
     * @param AnnotationReader  reader The AnnotationReader to use, duck-typed.
     * @param string|array|null paths  One or multiple paths where mapping classes can be found.
     */
    public function __construct(reader, paths = null)
    {
        let this->reader = reader;
        if paths {
            this->addPaths(paths);
        }
    }

    /**
     * Appends lookup paths to metadata driver.
     *
     * @param array paths
     *
     * @return void
     */
    public function addPaths(array paths)
    {
        let this->paths = array_unique(array_merge(this->paths, paths));
    }

    /**
     * Retrieves the defined metadata lookup paths.
     *
     * @return array
     */
    public function getPaths()
    {
        return this->paths;
    }

    /**
     * Append exclude lookup paths to metadata driver.
     *
     * @param array paths
     */
    public function addExcludePaths(array paths)
    {
        let this->excludePaths = array_unique(array_merge(this->excludePaths, paths));
    }

    /**
     * Retrieve the defined metadata lookup exclude paths.
     *
     * @return array
     */
    public function getExcludePaths()
    {
        return this->excludePaths;
    }

    /**
     * Retrieve the current annotation reader
     *
     * @return AnnotationReader
     */
    public function getReader()
    {
        return this->reader;
    }

    /**
     * Gets the file extension used to look for mapping files under.
     *
     * @return string
     */
    public function getFileExtension()
    {
        return this->fileExtension;
    }

    /**
     * Sets the file extension used to look for mapping files under.
     *
     * @param string fileExtension The file extension to set.
     *
     * @return void
     */
    public function setFileExtension(fileExtension)
    {
        let this->fileExtension = fileExtension;
    }

    /**
     * Returns whether the class with the specified name is transient. Only non-transient
     * classes, that is entities and mapped superclasses, should have their metadata loaded.
     *
     * A class is non-transient if it is annotated with an annotation
     * from the {@see AnnotationDriver::entityAnnotationClasses}.
     *
     * @param string className
     *
     * @return boolean
     */
    public function isTransient(className)
    {
        var classAnnotations, annot;

        let classAnnotations = this->reader->getClassAnnotations(new \ReflectionClass(className));

        for annot in classAnnotations {
            if isset this->entityAnnotationClasses[get_class(annot)] {
                return false;
            }
        }
        return true;
    }

    /**
     * {@inheritDoc}
     */
    public function getAllClassNames()
    {
        var classes, includedFiles, path, iterator, file, sourceFile, excludePath, exclude, current, declared, className, rc;

        if this->classNames !== null {
            return this->classNames;
        }

        if !this->paths {
            throw MappingException::pathRequired();
        }

        let classes = [];
        let includedFiles = [];

        for path in this->paths {
            if  !is_dir(path) {
                throw MappingException::fileMappingDriversRequireConfiguredDirectoryPath(path);
            }

            let iterator = new \RegexIterator(
                new \RecursiveIteratorIterator(
                    new \RecursiveDirectoryIterator(path, \FilesystemIterator::SKIP_DOTS),
                    \RecursiveIteratorIterator::LEAVES_ONLY
                ),
                "/^.+" . preg_quote(this->fileExtension) . "/i",
                \RecursiveRegexIterator::GET_MATCH
            );

            for file in iterator {
                let sourceFile = file[0];

                if !preg_match("(^phar:)i", sourceFile) {
                    let sourceFile = realpath(sourceFile);
                }

                for excludePath in this->excludePaths {
                    let exclude = str_replace("\\", "/", realpath(excludePath));
                    let current = str_replace("\\", "/", sourceFile);

                    if strpos(current, exclude) !== false {
                        continue;
                    }
                }

                require_once(sourceFile);

                let includedFiles[] = sourceFile;
            }
        }

        let declared = get_declared_classes();

        for className in declared {
            let rc = new \ReflectionClass(className);
            let sourceFile = rc->getFileName();
            if in_array(sourceFile, includedFiles) && ! this->isTransient(className) {
                let classes[] = className;
            }
        }

        let this->classNames = classes;

        return classes;
    }
}
