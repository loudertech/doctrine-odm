PHP_ARG_ENABLE(doctrine, whether to enable doctrine, [ --enable-doctrine   Enable Doctrine])

if test "$PHP_DOCTRINE" = "yes"; then
	AC_DEFINE(HAVE_DOCTRINE, 1, [Whether you have Doctrine])
	doctrine_sources="doctrine.c kernel/main.c kernel/memory.c kernel/exception.c kernel/hash.c kernel/debug.c kernel/backtrace.c kernel/object.c kernel/array.c kernel/extended/array.c kernel/string.c kernel/fcall.c kernel/require.c kernel/file.c kernel/operators.c kernel/concat.c kernel/variables.c kernel/filter.c kernel/iterator.c kernel/exit.c doctrine/mongodb/cursor.zep.c
	doctrine/mongodb/iterator.zep.c
	doctrine/odm/mongodb/cursor.zep.c
	doctrine/odm/mongodb/documentmanager.zep.c
	doctrine/odm/mongodb/events.zep.c
	doctrine/odm/mongodb/hydrator/hydratorfactory.zep.c
	doctrine/odm/mongodb/lockmode.zep.c
	doctrine/odm/mongodb/persisters/collectionpersister.zep.c "
	PHP_NEW_EXTENSION(doctrine, $doctrine_sources, $ext_shared)

	old_CPPFLAGS=$CPPFLAGS
	CPPFLAGS="$CPPFLAGS $INCLUDES"

	AC_CHECK_DECL(
		[HAVE_BUNDLED_PCRE],
		[
			AC_CHECK_HEADERS(
				[ext/pcre/php_pcre.h],
				[
					PHP_ADD_EXTENSION_DEP([doctrine], [pcre])
					AC_DEFINE([ZEPHIR_USE_PHP_PCRE], [1], [Whether PHP pcre extension is present at compile time])
				],
				,
				[[#include "main/php.h"]]
			)
		],
		,
		[[#include "php_config.h"]]
	)

	AC_CHECK_DECL(
		[HAVE_JSON],
		[
			AC_CHECK_HEADERS(
				[ext/json/php_json.h],
				[
					PHP_ADD_EXTENSION_DEP([doctrine], [json])
					AC_DEFINE([ZEPHIR_USE_PHP_JSON], [1], [Whether PHP json extension is present at compile time])
				],
				,
				[[#include "main/php.h"]]
			)
		],
		,
		[[#include "php_config.h"]]
	)

	CPPFLAGS=$old_CPPFLAGS
fi
