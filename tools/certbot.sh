#!/bin/bash

docker run -v $PWD/letsencrypt:/etc/letsencrypt -v $PWD/static/:/var/lib/letsencrypt certbot/certbot:latest $@
