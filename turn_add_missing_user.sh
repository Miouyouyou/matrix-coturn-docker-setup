#!/bin/bash
echo "If a Docker error occurs, be sure to run this script with"
echo "the right privileges"
echo ""
docker exec coturn turnadmin -a -b "/srv/coturn/turndb" -u "xQ0YoVkyDqNfMHZ8t3RHUQp5acMEICf6" -p "kur5oQqmeXsI6ejMKNJ13VggA9HPokOe" -r "testturn.miouyouyou.fr"
