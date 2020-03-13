#!/bin/bash


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
	./certbot.sh "certonly --dry-run --agree-tos --email $email_address --webroot -w /var/lib/letsencrypt -d  $certbot_domain_args" &&
	cp -rL "letsencrypt/live/$main_domain" ssl/
}

docker_stop_nginx() {
	echo "Stowping"
	docker-compose down
}


bail_out() {
	exit_status=$1
	docker_stop_nginx
	exit $exit_status
}

print_usage() {
	echo "./letsencrypt_generate.sh contact@mail.com domain.com [another.domain.com ...]"
}


if [ ! -f ./certbot.sh ];
then
	echo "The certbot wrapper ./certbot.sh is missing :C"
	bail_out 3
fi

if [ "$#" -lt 2 ];
then
	print_usage
	bail_out 1
fi

if [ -f "letsencrypt/live/$1/fullchain.pem" ];
then
	echo "Certificates seem to exist for $1"
	echo "If you want to renew certificates, use ./letsencrypt_renew.sh"
	echo "If you want to regenerate them, move away letsencrypt/live/$1"
	bail_out 2
fi

echo "If you get a Docker error, be sure to run the script with"
echo "the right privileges."
echo ""

docker_start_nginx &&
letsencrypt_generate_certificates "$@" &&
docker_stop_nginx || bail_out 4
