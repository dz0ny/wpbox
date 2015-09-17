#!/bin/bash
set -e

env

if [[ "$1" == apache2* ]] || [ "$1" == php-fpm ]; then
	if [ -n "$MYSQL_PORT_3306_TCP" ]; then
		if [ -z "$WORDPRESS_DB_HOST" ]; then
			WORDPRESS_DB_HOST='mysql'
		else
			echo >&2 'warning: both WORDPRESS_DB_HOST and MYSQL_PORT_3306_TCP found'
			echo >&2 "  Connecting to WORDPRESS_DB_HOST ($WORDPRESS_DB_HOST)"
			echo >&2 '  instead of the linked mysql container'
		fi
	fi

	if [ -z "$WORDPRESS_DB_HOST" ]; then
		echo >&2 'error: missing WORDPRESS_DB_HOST and MYSQL_PORT_3306_TCP environment variables'
		echo >&2 '  Did you forget to --link some_mysql_container:mysql or set an external db'
		echo >&2 '  with -e WORDPRESS_DB_HOST=hostname:port?'
		exit 1
	fi

	# if we're linked to MySQL, and we're using the root user, and our linked
	# container has a default "root" password set up and passed through... :)
	: ${WORDPRESS_DB_USER:=root}
	if [ "$WORDPRESS_DB_USER" = 'root' ]; then
		: ${WORDPRESS_DB_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}
	fi
	: ${WORDPRESS_DB_NAME:=wordpress}

	if [ -z "$WORDPRESS_DB_PASSWORD" ]; then
		echo >&2 'error: missing required WORDPRESS_DB_PASSWORD environment variable'
		echo >&2 '  Did you forget to -e WORDPRESS_DB_PASSWORD=... ?'
		echo >&2
		echo >&2 '  (Also of interest might be WORDPRESS_DB_USER and WORDPRESS_DB_NAME.)'
		exit 1
	fi

	if ! [ -e index.php -a -e wp-includes/version.php ]; then
		echo >&2 "WordPress not found in $(pwd) - copying now..."
		if [ "$(ls -A)" ]; then
			echo >&2 "WARNING: $(pwd) is not empty - press Ctrl+C now if this is an error!"
			( set -x; ls -A; sleep 10 )
		fi
		tar cf - --one-file-system -C /usr/src/wordpress . | tar xf -
		echo >&2 "Complete! WordPress has been successfully copied to $(pwd)"
		if [ ! -e .htaccess ]; then
			# NOTE: The "Indexes" option is disabled in the php:apache base image
			cat > .htaccess <<-'EOF'
				# BEGIN WordPress
				<IfModule mod_rewrite.c>
				RewriteEngine On
				RewriteBase /
				RewriteRule ^index\.php$ - [L]
				RewriteCond %{REQUEST_FILENAME} !-f
				RewriteCond %{REQUEST_FILENAME} !-d
				RewriteRule . /index.php [L]
				</IfModule>
				# END WordPress
			EOF
			chown www-data:www-data .htaccess
		fi
	fi

	# TODO handle WordPress upgrades magically in the same way, but only if wp-includes/version.php's $wp_version is less than /usr/src/wordpress/wp-includes/version.php's $wp_version

	if [ ! -e wp-config.php ]; then
		awk '/^\/\*.*stop editing.*\*\/$/ && c == 0 { c = 1; system("cat") } { print }' wp-config-sample.php > wp-config.php <<'EOPHP'
// If we're behind a proxy server and using HTTPS, we need to alert Wordpress of that fact
// see also http://codex.wordpress.org/Administration_Over_SSL#Using_a_Reverse_Proxy
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
	$_SERVER['HTTPS'] = 'on';
}

EOPHP
		chown www-data:www-data wp-config.php
	fi

	# see http://stackoverflow.com/a/2705678/433558
	sed_escape_lhs() {
		echo "$@" | sed 's/[]\/$*.^|[]/\\&/g'
	}
	sed_escape_rhs() {
		echo "$@" | sed 's/[\/&]/\\&/g'
	}
	php_escape() {
		php -r 'var_export((string) $argv[1]);' "$1"
	}
	set_config() {
		key="$1"
		value="$2"
		regex="(['\"])$(sed_escape_lhs "$key")\2\s*,"
		if [ "${key:0:1}" = '$' ]; then
			regex="^(\s*)$(sed_escape_lhs "$key")\s*="
		fi
		sed -ri "s/($regex\s*)(['\"]).*\3/\1$(sed_escape_rhs "$(php_escape "$value")")/" wp-config.php
	}

	set_config 'DB_HOST' "$WORDPRESS_DB_HOST"
	set_config 'DB_USER' "$WORDPRESS_DB_USER"
	set_config 'DB_PASSWORD' "$WORDPRESS_DB_PASSWORD"
	set_config 'DB_NAME' "$WORDPRESS_DB_NAME"

	if [ "$WORDPRESS_TABLE_PREFIX" ]; then
		set_config '$table_prefix' "$WORDPRESS_TABLE_PREFIX"
	fi

	TERM=dumb php -- "$WORDPRESS_DB_HOST" "$WORDPRESS_DB_USER" "$WORDPRESS_DB_PASSWORD" "$WORDPRESS_DB_NAME" <<'EOPHP'
<?php
// database might not exist, so let's try creating it (just to be safe)

$stderr = fopen('php://stderr', 'w');

list($host, $port) = explode(':', $argv[1], 2);

$maxTries = 10;
do {
	$mysql = new mysqli($host, $argv[2], $argv[3], '', (int)$port);
	if ($mysql->connect_error) {
		fwrite($stderr, "\n" . 'MySQL Connection Error: (' . $mysql->connect_errno . ') ' . $mysql->connect_error . "\n");
		--$maxTries;
		if ($maxTries <= 0) {
			exit(1);
		}
		sleep(3);
	}
} while ($mysql->connect_error);

if (!$mysql->query('CREATE DATABASE IF NOT EXISTS `' . $mysql->real_escape_string($argv[4]) . '`')) {
	fwrite($stderr, "\n" . 'MySQL "CREATE DATABASE" Error: ' . $mysql->error . "\n");
	$mysql->close();
	exit(1);
}

$mysql->close();
EOPHP
fi

echo "[php]" > /usr/local/etc/php/conf.d/env.ini
echo "env[MYSQL_SERVER_HOST] = $WORDPRESS_DB_HOST" > /usr/local/etc/php/conf.d/env.ini
echo "env[MAIL_HOST] = $MAILHOG_PORT_1025_TCP_ADDR" > /usr/local/etc/php/conf.d/env.ini
echo "date.timezone = ${TIMEZONE-UTC}" >> /usr/local/etc/php/conf.d/env.ini
echo "post_max_size = ${POST_MAX_SIZE-2000M}" >> /usr/local/etc/php/conf.d/env.ini
echo "max_execution_time = ${MAX_EXECUTION_TIME-3000}" >> /usr/local/etc/php/conf.d/env.ini
echo "max_input_time = ${MAX_INPUT_TIME-3000}" >> /usr/local/etc/php/conf.d/env.ini
echo "upload_max_filesize = ${UPLOAD_MAX_FILESIZE-2000M}" >> /usr/local/etc/php/conf.d/env.ini
echo "xdebug.remote_enable=1" >> /usr/local/etc/php/conf.d/env.ini
echo "xdebug.remote_host=${XDEBUG_IP-172.17.42.1}" >> /usr/local/etc/php/conf.d/env.ini
echo "xdebug.remote_connect_back=1" >> /usr/local/etc/php/conf.d/env.ini
echo "xdebug.remote_port=${XDEBUG_PORT-9000}" >> /usr/local/etc/php/conf.d/env.ini
echo "xdebug.remote_handler=dbgp" >> /usr/local/etc/php/conf.d/env.ini
echo "xdebug.remote_mode=req" >> /usr/local/etc/php/conf.d/env.ini
echo "xdebug.remote_autostart=true" >> /usr/local/etc/php/conf.d/env.ini

if [ -n "${THEME+1}" ]; then
	echo "Installing theme $THEME"
	wget -O $THEME.zip http://wpapi.herokuapp.com/theme/$THEME/download
	unzip $THEME.zip -d ./wp-content/themes
	rm $THEME.zip
	echo "Finished installing theme $THEME"
fi

if [ -n "${PLUGIN+1}" ]; then
	echo "Installing plugin $PLUGIN"
	wget -O $PLUGIN.zip http://wpapi.herokuapp.com/plugin/$PLUGIN/download
	unzip $PLUGIN.zip -d ./wp-content/plugins
	rm $THEME.zip
	echo "Finished installing plugin $PLUGIN"
fi

exec "$@"
