#!/bin/sh

CONFIGURATION_DIR=/etc/synapse
CONFIGURATION_FILEPATH=$CONFIGURATION_DIR/homeserver.yaml
CONFIGURATION_SPLITDIR=$CONFIGURATION_DIR/homeserver.d
CONFIGURATION_DB_FILEPATH=$CONFIGURATION_SPLITDIR/database.yaml
CONFIGURATION_VOIP_FILEPATH=$CONFIGURATION_SPLITDIR/voip.yaml
CONFIGURATION_REGISTRATION_FILEPATH=$CONFIGURATION_SPLITDIR/registration.yaml
CONFIGURATION_KEYS_DIR=$CONFIGURATION_DIR/keys
DATA_DIR=/var/cache/synapse

ERROR_CODE_ENVIRONMENT_VARIABLES_NOT_SET=1
ERROR_CODE_UNSUPPORTED_DATABASE_BACKEND=2
ERROR_CODE_ENVIRONMENT_VARIABLES_NOT_SET_POSTGRES=3

# This forces the reconfiguration if the first configuration
# failed midway, generating a homeserver.yaml without other
# required files

FIRST_CONFIG_LOCK_FILEPATH=$CONFIGURATION_DIR/CONFIGURED

DB_BACKEND_NAME_POSTGRESQL="postgresql"
DB_BACKEND_NAME_SQLITE="sqlite"

generate_secret() {
	echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
}

generate_registration_configuration() {
	cat << EOF > "$CONFIGURATION_REGISTRATION_FILEPATH"
enable_registration: False
registration_shared_secret: $(generate_secret)
EOF
}


# The configuration tool from synapse is currently unable
# to configure the database part.
generate_database_configuration_postgres() {
	dbhost="$1"
	dbname="$2"
	dbuser="$3"
	dbpass="$4"
	cat << EOF > "$CONFIGURATION_DB_FILEPATH"
database:
  name: psycopg2
  args:
    host: $dbhost
    database: $dbname
    user: $dbuser
    password: $dbpass
EOF
	cat "$CONFIGURATION_DB_FILEPATH"
}

generate_database_configuration_sqlite() {
	cat << EOF > "$CONFIGURATION_DB_FILEPATH"
database:
  name: sqlite
  args:
    $DATA_DIR/synapse.db
EOF
}

generate_turn_configuration() {
	# While Synapse support multiple URI for TURN
	# defining an array of URI through environment variables is
	# kind of a pain
	# We could always some sort of delimiter, but I'd rather generate
	# a simple configuration file and let the user edit it if they're
	# dealing with a very complex setup
	turn_main_uri=$1
	turn_user=$2
	turn_password=$3
	cat << EOF > "$CONFIGURATION_VOIP_FILEPATH"
turn_uris: ["$turn_main_uri"]
turn_username: "$turn_user"
turn_password: "$turn_password"
EOF
}

synapse_is_configured() {
	[    -d "$CONFIGURATION_DIR" \
	  -a -f "$CONFIGURATION_FILEPATH" \
	  -a -d "$CONFIGURATION_KEYS_DIR" \
	  -a -f "$FIRST_CONFIG_LOCK_FILEPATH" ];
}

database_backend_not_supported() {
	provided_backend="$1"
	[    ! "$provided_backend" = "$DB_BACKEND_NAME_POSTGRESQL" \
	  -a ! "$provided_backend" = "$DB_BACKEND_NAME_SQLITE" ];
}

not_defined() {
	env_var=$1
	[ -n "$env_var" ]
}

strip_barebone() {
	commented_filepath=$1
	uncommented_filepath=$2
	grep -v '#' $commented_filepath | grep . > $uncommented_filepath
}

write_lock_file() {
	lockfile_path="$1"
	cat << EOF > $lockfile_path
# File generated by Myy's Docker image
# If you remove this, the configuration generation tools will be
# invoked again.
# Note that Synapse configuration tools refuse to regenerate
# homeserver.yaml files when present.
EOF
}

synapse_configure() {

	if [   -z "$SYNAPSE_SERVER_NAME" \
	    -o -z "$SYNAPSE_SERVER_ADDRESS" \
	    -o -z "$SYNAPSE_REPORT_STATS" \
	    -o -z "$SYNAPSE_DATABASE_BACKEND" \
	    -o -z "$SYNAPSE_VOIP_TURN_MAIN_URL" \
	    -o -z "$SYNAPSE_VOIP_TURN_USERNAME" \
	    -o -z "$SYNAPSE_VOIP_TURN_PASSWORD" ];
	then
		echo "In order to generate the first configuration file"
		echo "You should define the following environment variables :"
		echo "- SYNAPSE_SERVER_NAME (currently : $SYNAPSE_SERVER_NAME)"
		echo "- SYNAPSE_SERVER_ADDRESS (currently : $SYNAPSE_SERVER_ADDRESS)"
		echo "- SYNAPSE_REPORT_STATS (currently : $SYNAPSE_REPORT_STATS)"
		echo "- SYNAPSE_DATABASE_BACKEND (currently : $SYNAPSE_DATABASE_BACKEND)"
		echo "- SYNAPSE_VOIP_TURN_MAIN_URL (currently : $SYNAPSE_VOIP_TURN_MAIN_URL)"
		echo "- SYNAPSE_VOIP_TURN_USERNAME (currently : $SYNAPSE_VOIP_TURN_USERNAME)"
		echo "- SYNAPSE_VOIP_TURN_PASSWORD (currently : $SYNAPSE_VOIP_TURN_PASSWORD)"
		exit $ERROR_CODE_ENVIRONMENT_VARIABLES_NOT_SET
	fi

	if database_backend_not_supported $SYNAPSE_DATABASE_BACKEND;
	then
		echo "SYNAPSE_DATABASE_BACKEND can only be either :"
		echo "  postgresql"
		echo "  sqlite"
		echo "Current value : $SYNAPSE_DATABASE_BACKEND"
		exit $ERROR_CODE_UNSUPPORTED_DATABASE_BACKEND
	fi

	if [ "$SYNAPSE_DATABASE_BACKEND" = $DB_BACKEND_NAME_POSTGRESQL ];
	then
		if [ ! -f "$CONFIGURATION_DB_FILEPATH" ];
		then
			if [    -z "$SYNAPSE_POSTGRES_DBADDR" \
			     -o -z "$POSTGRES_DB" \
			     -o -z "$POSTGRES_USER" \
			     -o -z "$POSTGRES_PASSWORD" ];
			then
				echo "In order to generate the database configuration file"
				echo "You need to set up the following environment variables :"
				echo "- SYNAPSE_POSTGRES_DBADDR (currently : $SYNAPSE_POSTGRES_DBADDR)"
				echo "- POSTGRES_DB (currently : $POSTGRES_DB)"
				echo "- POSTGRES_USER (currently : $POSTGRES_USER)"
				echo "- POSTGRES_PASSWORD (currently : $POSTGRES_PASSWORD)"
				echo "Alternatively, create your own configuration file at $CONFIGURATION_DB_FILEPATH"
				exit $ERROR_CODE_ENVIRONMENT_VARIABLES_NOT_SET_POSTGRES
			fi
		fi
	fi

	mkdir -p "$CONFIGURATION_DIR"
	mkdir -p "$DATA_DIR"
	mkdir -p "$CONFIGURATION_SPLITDIR"
	mkdir -p "$CONFIGURATION_KEYS_DIR"

	echo "Executing python"
	echo "synapse.app.homeserver"
	echo "--config-dir=$CONFIGURATION_DIR"
	echo "--config-path=$CONFIGURATION_FILEPATH.sample"
	echo "--config-path=$CONFIGURATION_SPLITDIR"
	echo "--data-dir=$DATA_DIR"
	echo "--keys-dir=$CONFIGURATION_KEYS_DIR"
	echo "--report-stats=$SYNAPSE_REPORT_STATS"
	echo "--generate-config"
	echo "-H $SYNAPSE_SERVER_NAME"
	echo "--generate-keys"
	echo "--open-private-ports"

	python \
		-m synapse.app.homeserver \
		--config-dir="$CONFIGURATION_DIR" \
		--config-path="$CONFIGURATION_FILEPATH".sample \
		--config-path="$CONFIGURATION_SPLITDIR" \
		--data-dir="$DATA_DIR" \
		--keys-dir="$CONFIGURATION_KEYS_DIR" \
		--report-stats="$SYNAPSE_REPORT_STATS" \
		--generate-config \
		-H "$SYNAPSE_SERVER_NAME" \
		--generate-keys \
		--open-private-ports

	# My shell-fu is really failing me
	if [ $? -ne 0 ]; then
		echo "Synapse failed to generate the main configuration file"
		exit 4
	fi

	strip_barebone $CONFIGURATION_FILEPATH.sample $CONFIGURATION_FILEPATH

	if [ ! -f "$CONFIGURATION_DB_FILEPATH" ];
	then
		# A case-switch would be better
		# But the case switch syntax of shell scripts is horrendous
		if [ "$SYNAPSE_DATABASE_BACKEND" = "$DB_BACKEND_NAME_POSTGRESQL" ];
		then
			generate_database_configuration_postgres \
				"$SYNAPSE_POSTGRES_DBADDR"\
				"$POSTGRES_DB"\
				"$POSTGRES_USER"\
				"$POSTGRES_PASSWORD"
		elif [ "$SYNAPSE_DATABASE_BACKEND" = "$DB_BACKEND_NAME_SQLITE" ]
		then
			generate_database_configuration_sqlite
		fi
	fi

	if [ ! -f "$CONFIGURATION_VOIP_FILEPATH" ];
	then
		generate_turn_configuration \
			"$SYNAPSE_VOIP_TURN_MAIN_URL" \
			"$SYNAPSE_VOIP_TURN_USERNAME" \
			"$SYNAPSE_VOIP_TURN_PASSWORD"
	fi

	generate_registration_configuration

	write_lock_file "$FIRST_CONFIG_LOCK_FILEPATH"

}

synapse_start() {
	python \
		-m synapse.app.homeserver \
		--config-path="$CONFIGURATION_FILEPATH" \
		--config-path="$CONFIGURATION_SPLITDIR" \
		--data-dir="$DATA_DIR" \
		$@
}

synapse_is_configured || synapse_configure

if [ $? -eq 0 ]; then
	synapse_start $@
fi

