#!/bin/bash 

print_usage() {
	echo "./synapse_add_user.sh username password"
}

print_advice() {
	echo "Failed to run docker-compose exec synapse ..."
	echo "Be sure to run this script with enough privileges to run"
	echo "Docker, and be sure that the docker services are 'up'"
	echo
	echo "Check with docker stats and enable them with"
	echo "docker-compose up"
}

if [ "$#" -lt 2 ];
then
	print_usage
	exit 1
fi

user="$1"
password="$2"

docker-compose exec synapse register_new_matrix_user -c /etc/synapse/homeserver.d/registration.yaml -u $user -p $password -a http://localhost:8008 || print_advice
