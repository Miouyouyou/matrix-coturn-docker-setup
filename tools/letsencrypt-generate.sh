#!/bin/bash

CERTBOT_FILEPATH="./tools/certbot.sh"

join_by() {
	separator=$1
	shift
	echo -n "$1"
	shift
	printf "%s" "${@/#/$separator}"
}

docker_start_nginx() {
	docker-compose down &&
	mkdir -p ssl &&
	docker-compose run -p 80:80 -d nginx
}

letsencrypt_generate_certificates() {
	email_address=$1
	shift
	main_domain=$1
	certbot_domain_args="$(join_by " -d " $@)"
	$CERTBOT_FILEPATH "certonly --agree-tos --email $email_address --webroot -w /var/lib/letsencrypt -d  $certbot_domain_args" &&
	cp -rL "letsencrypt/live/$main_domain" ssl/ &&
	# Note : the only purpose of this part is to make
	# docker-generate.sh script run correctly, since
	# this script check that SSL certificates are available
	# for the MATRIX domain and the TURN domain...
	shift &&
	for sub_domain in $@;
	do
		# ln -s can be quite unreliable
		# And symbolic links TOO can be unreliable in containers
		# Just copy them. This should only waste a few kilo-bytes at
		# worst.
		cp -rL "ssl/$main_domain" ssl/$sub_domain
	done
}

docker_stop_nginx() {
	echo "Making sure that every started Docker service is stopped..."
	docker-compose down
}

bail_out() {
	exit_status=$1
	docker_stop_nginx
	exit $exit_status
}

print_usage() {
	echo "$0 contact@mail.com domain.com [another.domain.com ...]"
}

if [ ! -f $CERTBOT_FILEPATH ];
then
	echo "Cannot find the certbot script at $CERTBOT_FILEPATH :C"
	bail_out 3
fi

if [ "$#" -lt 2 ];
then
	print_usage
	bail_out 1
fi

if [ -f "letsencrypt/live/$2/fullchain.pem" ];
then
	echo "Certificates seem to exist for $2"
	echo "If you want to renew certificates, use ./letsencrypt_renew.sh"
	echo "If you want to regenerate them, move away letsencrypt/live/$2"
	bail_out 2
fi

echo "If you get a Docker error, be sure to run the script with"
echo "the right privileges."
echo ""

docker_start_nginx &&
letsencrypt_generate_certificates "$@" &&
docker_stop_nginx || bail_out 4
