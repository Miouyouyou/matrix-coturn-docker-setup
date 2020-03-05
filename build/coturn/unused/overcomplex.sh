#!/bin/sh

COTURN_CONFIGURATION_FILEPATH=/etc/turnserver.conf
COTURN_CONFIG_LOCK_FILE=$COTURN_CONFIGURATION_FILEPATH.configured
COTURN_SQLITE_FILEPATH=/srv/coturn/turndb
COTURN_SQLITE_TEMPLATE_FILEPATH=/usr/local/var/db/turndb

ERROR_CODE_ENVIRONMENT_VARIABLES_NOT_SET=1
ERROR_CODE_COULD_NOT_SETUP_SQLITE=2

coturn_conf_generate() {
	turn_domain_name="$1"
	turn_cli_password="$2"
	cat << EOF > "$COTURN_CONFIGURATION_FILEPATH"
listening-port=3478
tls-listening-port=5349

# Relay ports
# Myy: Some browsers and testing tools seem to expect these ports.
# If you change them, you might not be able to use these
# tools, and some browsers might not behave correctly.
min-port=49152
max-port=65535
verbose

fingerprint
lt-cred-mech

# Replace 'turn.example.com' by your TURN domain name
realm=$turn_domain_name

syslog

cli-ip=127.0.0.1
cli-port=5766
cli-password=$turn_cli_password
EOF
}

coturn_conf_add_ssl() {
	ssl_cert_filepath="$1"
	ssl_privkey_filepath="$2"
	# Reminder :
	# The '>>' is important for appending to the current
	# configuration file. '>' would overwrite the
	# current configuration file, 
	cat << EOF >> "$COTURN_CONFIGURATION_FILEPATH" 
cert=$ssl_cert_filepath
pkey=$ssl_privkey_filepath
EOF
}

coturn_conf_add_nat() {
	public_ip="$1"
	internal_ip="$2"
	cat << EOF >> "$COTURN_CONFIGURATION_FILEPATH"
external-ip=$internal_ip/$public_ip
EOF
}

coturn_prepare_sqlite_database() {
	database_filepath="$1"
	database_template_filepath="$2"
	cp $database_template_filepath $database_filepath
	# TODO Show the error message but let the main
	# script handle the exit with error code.
	if [ $? -ne 0 ];
	then
		echo "Failed to execute cp $database_template_filepath $database_filepath"
		echo "Could not copy the SQLite template."
		exit $ERROR_CODE_COULD_NOT_SETUP_SQLITE
	fi
	cat << EOF >> "$COTURN_CONFIGURATION_FILEPATH"
userdb=$database_filepath
EOF
}

write_lock_file() {
	lock_file="$1"
	cat << EOF > "$lock_file"
# This file indicates to the Docker start script that
# COTURN is configured.
# Removing it will provoke a reconfiguration.
EOF
}

ip_invalid() {
	provided_ip="$1"
	# It's a lie !
	# I only check that some string were provided.
	# A potential enhancement would be to check the IP...
	# Note that the IP has be an IP, not a domain name,
	# due to the main code using inet_pton instead of
	# getaddrinfo
	[ -z "$provided_ip" ]
}

coturn_add_user() {
	username="$1"
	password="$2"
	domain="$3"
	database_filepath="$4"
	turnadmin -a -b $database_filepath -u $username -p $password -r $domain
}

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

# TODO
# Add support for multiple databases format
# (Postgres, Redis, ...) by :
# 1. Setting up the database, using the various schemas
#    provided in /usr/local/turndb, and the credentials
#    provided.
# 2. Adding the configuration entries in the configuration
#    file.


coturn_configure() {

	# Check all variables first. Avoid last minute surprises.
	if [ -z "$TURN_DOMAIN_NAME" -o -z "$COTURN_CLI_PASSWORD" ];
	then
		echo "For the generation of the first configuration"
		echo "Please setup the following environment variables :"
		echo "  TURN_DOMAIN_NAME     (currently $TURN_DOMAIN_NAME)"
		echo "  COTURN_CLI_PASSWORD  (currently $COTURN_CLI_PASSWORD)"
		exit $ERROR_CODE_ENVIRONMENT_VARIABLES_NOT_SET
	fi

	coturn_conf_generate "$TURN_DOMAIN_NAME" "$COTURN_CLI_PASSWORD"

	if [ -n "$SSL_CERT_FILEPATH" -a -n "$SSL_PRIVKEY_FILEPATH" ];
	then
		coturn_conf_add_ssl "$SSL_CERT_FILEPATH" "$SSL_PRIVKEY_FILEPATH"
	fi

	if [ -n "$NAT_PUBLIC_IP" ];
	then
		if ip_invalid "$NAT_PRIVATE_IP";
		then
			NAT_PRIVATE_IP=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')
		fi
		coturn_conf_add_nat "$NAT_PUBLIC_IP" "$NAT_PRIVATE_IP"
	fi

	# TODO As stated earlier, add database support
	coturn_prepare_sqlite_database "$COTURN_SQLITE_FILEPATH" "$COTURN_SQLITE_TEMPLATE_FILEPATH"
	if [ $? -ne 0 ];
	then
		echo "Could not prepare the database correctly"
		echo "Exiting."
		exit $ERROR_CODE_COULD_NOT_SETUP_SQLITE
	fi

	if [ -n "$TURN_USER" -a -n "$TURN_PASSWORD" ];
	then
		coturn_add_user "$TURN_USER" "$TURN_PASSWORD" "$TURN_DOMAIN_NAME" "$COTURN_SQLITE_FILEPATH"
	fi

	write_lock_file "$COTURN_CONFIG_LOCK_FILE"
}

coturn_is_configured() {
	[ -f "$COTURN_CONFIG_LOCK_FILE" ];
}

coturn_is_configured || coturn_configure

turnserver $START_PARAMS $@
