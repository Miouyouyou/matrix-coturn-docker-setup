#!/bin/sh

COTURN_CONFIG_LOCK_FILE=/etc/turnserver.conf.configured
COTURN_SQLITE_FILEPATH=/srv/coturn/turndb
COTURN_SQLITE_TEMPLATE_FILEPATH=/usr/local/var/db/turndb

write_lock_file() {
	lock_file="$1"
	cat << EOF > "$COTURN_CONFIG_LOCK_FILE"
# Setup and checked by the Docker start script.
# If you remove this file, the configuration tools
# will be executed again, overwriting previous
# configurations and databases.

$(date)

EOF
}

coturn_prepare_sqlite_database() {
	database_filepath="$1"
	database_template_filepath="$2"
	cp $database_template_filepath $database_filepath

}

coturn_database_prepared() {
	[ -f $COTURN_SQLITE_FILEPATH -a -f $COTURN_CONFIG_LOCK_FILE ]
}

coturn_add_user() {
	username="$1"
	password="$2"
	domain="$3"
	database_filepath="$4"
	turnadmin -a -b $database_filepath -u $username -p $password -r $domain
}

coturn_prepare_database() {

	# TODO
	# Add support for multiple databases format
	# (Postgres, Redis, ...) by :
	# 1. Setting up the database, using the various schemas
	#    provided in /usr/local/turndb, and the credentials
	#    provided.
	# 2. Adding the configuration entries in the configuration
	#    file.

	coturn_prepare_sqlite_database "$COTURN_SQLITE_FILEPATH" "$COTURN_SQLITE_TEMPLATE_FILEPATH"

	if [ $? -ne 0 ];
	then
		echo "Failed to execute cp $COTURN_SQLITE_FILEPATH $COTURN_SQLITE_TEMPLATE_FILEPATH"
		echo "Could not copy the SQLite template."
		echo "Exiting."
		exit $ERROR_CODE_COULD_NOT_SETUP_SQLITE
	fi

	if [ -n "$TURN_USER" -a -n "$TURN_PASSWORD" -a -n "$TURN_DOMAIN_NAME" ];
	then
		coturn_add_user "$TURN_USER" "$TURN_PASSWORD" "$TURN_DOMAIN_NAME" "$COTURN_SQLITE_FILEPATH"
	fi
	
	write_lock_file "$COTURN_CONFIG_LOCK_FILE"
}

coturn_database_prepared || coturn_prepare_database

# turnserver $START_PARAMS $@
