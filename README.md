# About

This repository contains files to "quickly" setup a Matrix
Synapse server.  

Note that more complex setups can be done using
[Ansible](https://github.com/atb00ker/ansible-matrix-synapse)

# Usage

## First configuration

Quite a long-ride for a "quick" setup...

### SSL 

If you don't have SSL certificates, generate free Let's Encrypt SSL
certificates before hand.  
To do that you can use the method described below.

#### Conventions used in this document

##### Folders

`docker-compose.yml` is currently configured to use
**ssl/matrix.yourdomain.com/...** for SSL files related to your Matrix
domain and **ssl/turn.yourdomain.com/...** for SSL files related to
your TURN domain.  
The **Checklist** follows this logic.

If you use the same SSL certificates for both TURN and Matrix domains,
replace these references accordingly in `docker-compose.yml`.

##### Files

* `fullchain.pem` is a certificate containing the whole chain
of trust.
* `key.pem` is the private key associated with your certificate.  
* `complete.pem` is the concatenation of `fullchain.pem` and
`key.pem`

> If you change any of these filenames, remember to change them
> in the various configuration files.

#### Generate SSL certificates with Let's Encrypt

##### Prepare ssl/ and start NGINX for ACME challenges

> This is the only time we map NGINX directly to port 80.
> In the current setup, HAProxy is mapped to port 80 and
> handle HTTP connections.

```bash
docker-compose down # Shut down all services for the moment
mkdir -p ssl # Be sure that ssl/ exist
docker-compose run -p 80:80 -d nginx # Run only NGINX on port 80 for ACME challenges
```

##### Generate the certificates the first time

**For Matrix**

```bash
export SSL_DOMAIN=matrix.yourdomain.com
docker run -v $PWD/letsencrypt:/etc/letsencrypt -v $PWD/static/:/var/lib/letsencrypt certbot/certbot:latest certonly --agree-tos --email yourmail@yourdomain.com --webroot -w /var/lib/letsencrypt -d $SSL_DOMAIN
cp -rL letsencrypt/live/$SSL_DOMAIN ssl/
```

**For TURN**

```bash
export SSL_DOMAIN=turn.yourdomain.com
docker run -v $PWD/letsencrypt:/etc/letsencrypt -v $PWD/static/:/var/lib/letsencrypt certbot/certbot:latest certonly --agree-tos --email yourmail@yourdomain.com --webroot -w /var/lib/letsencrypt -d $SSL_DOMAIN
cp -rL letsencrypt/live/$SSL_DOMAIN ssl/
```

##### Shutdown NGINX

```bash
docker-compose down
```

#### If you have your own SSL certificates

If you generated SSL certificates yourself, using another
method :

* [ ] Create the folder **ssl/matrix.mynewchat.com/**
* [ ] Copy SSL certificates for `matrix.mynewchat.com` to
      **ssl/matrix.mynewchat.com/**
* [ ] Create the folder **ssl/turn.mynewchat.com/**
* [ ] Copy SSL certificates for `turn.mynewchat.com` to
      **ssl/turn.mynewchat.com**

#### In both cases, generate `complete.pem` for HAProxy

```
cd ssl/matrix.yourdomain.com
cat fullchain.pem privkey.pem > complete.pem
cd -
```

> If you don't do this now, when starting HAProxy through
> docker-compose, a folder **ssl/matrix.yourdomain.com/complete.pem**
> will be created automatically by Docker.  
> In such case, remove the **ssl/matrix.yourdomain.com/complete.pem**
> folder, then `cat` the files.

### DNS

* Prepare the following DNS entries for your domain

```dns
_matrix._tcp IN SRV  10 5 8448 matrix.example.com
_turn._udp   IN SRV  0 0 3478 turn.example.com.
_turn._tcp   IN SRV  0 0 3478 turn.example.com.
_turns._tcp  IN SRV  0 0 5349 turn.example.com.
_turn._udp   IN SRV  0 0 3478 turn.example.com.
_turn._tcp   IN SRV  0 0 3478 turn.example.com.
_turns._tcp  IN SRV  0 0 5349 turn.example.com.
```

### Postgres

* Edit **env/postgres.env** and setup the credentials
  you would like to use for this server instance.

> The PostgreSQL instance should NOT be accessible
> from the outside though, unless you understand
> what you're doing.

### Final checklist (once you got the SSL certificates)

Let's say that :
* your new domain name for your Matrix server is
  `matrix.mynewchat.com`
* your new domain name for your TURN server is
  `turn.mynewchat.com`

* [ ] Fork this repository
* [ ] Clone it `git clone https://github.com/YourUserName/matrix-coturn-docker-setup --depth 1`
* [ ] In **static/.well-known/matrix/server** change occurences of
      `matrix.yourdomain.com` to `matrix.mynewchat.com`
* [ ] In **docker-compose.yml** change occurences of
      `matrix.yourdomain.com` to `matrix.mynewchat.com`
* [ ] In **nginx/conf/nginx.conf** change occurences of
      `matrix.yourdomain.com` to `matrix.mynewchat.com`
* [ ] In **haproxy/conf/haproxy.cfg** change occurences of
      `matrix.yourdomain.com` to `matrix.mynewchat.com`
* [ ] In **docker-compose.yml** uncomment the following lines,
      by removing the first `#` character :
  * [ ] `#- ./ssl/turn.yourdomain.com/fullchain.pem:/etc/ssl/fullchain.pem:ro`
  * [ ] `#- ./ssl/turn.yourdomain.com/privkey.pem:/etc/ssl/privkey.pem:ro`
* [ ] In **docker-compose.yml** change occurences of
      `turn.yourdomain.com` to `turn.mynewchat.com`
* [ ] In **coturn/conf/turnserver.conf** change occurences of
      `turn.yourdomain.com` to `turn.mynewchat.com`
* [ ] In **coturn/conf/turnserver.conf** uncomment the following
      lines by removing the first `#` character :
  * [ ] `#cert=/etc/ssl/fullchain.pem`
  * [ ] `#pkey=/etc/ssl/key.pem`

* [ ] In **docker-compose.yml** edit the following properties,
      based on your preferences, by modifying the part after
      the '='. Avoid using quotes in the environment variables :
  * [ ] `- SYNAPSE_SERVER_NAME=NameOfYourMatrixServer`
  * [ ] `- SYNAPSE_REPORT_STATS=yes # Can be set to "no"`
  * [ ] `- SYNAPSE_VOIP_TURN_USERNAME=turn_username`
  * [ ] `- SYNAPSE_VOIP_TURN_PASSWORD=turn_password`

## Run it

* From this repo, run :

```bash
docker-compose up -d
```

## Add users

### To your Synapse server

```bash
docker-compose exec synapse register_new_matrix_user -c /etc/synapse/homeserver.d/registration.yaml -u chat_user -p chat_password -a http://localhost:8008
```

### To your TURN server

```bash
docker-compose exec coturn turnadmin -a -b "/srv/coturn/turndb" -u turn_username -p turn_password -r turn.yourdomain.com
```

TURN is used to help the users wanting to do direct VOIP
configure their firewalls, and NAT setup.  
This remove the complexity of VOIP communications, without
requiring a middleman server (who could record the entire
session).

> If `SYNAPSE_VOIP_TURN_USERNAME` is not set to an empty string in
> the matrix configuration part, the user should be added ASAP,
> else CoTURN will reject the authentication request and fail
> VOIP setups.

## View the logs

You can then use `docker-compose logs` to get the logs of every
units at once, or :
* `docker-compose logs --last=50 -f matrix` to follow Synapse logs
* `docker-compose logs --last=5 -f coturn` to follow COTURN logs
* `docker-compose logs -f postgresql` to follow PostgreSQL logs
* `docker-compose logs -f haproxy` to follow HAProxy logs
* See files in `nginx/logs` for NGINX logs

## Shut it down

* From this repo, run :

```bash
docker-compose down
```

# Afterwards

## Renew the certificates afterwards

If you generated the Let's Encrypt SSL certificates using the method
described in this document, here's how you can renew your certificates.

Execute the following comands while docker-compose is `up` :

```bash
docker run -v $PWD/letsencrypt:/etc/letsencrypt -v $PWD/static/:/var/lib/letsencrypt certbot/certbot:latest renew
cp -rL letsencrypt/live/* ssl/
cd ssl/matrix.yourdomain.com
cat fullchain.pem privkey.pem > complete.pem
cd -
docker-compose kill -s SIGHUP haproxy # Tell HAProxy to reread its config and the SSL certificates
```

# Configurations

## HAProxy (Load balancer - Reverse proxy)

Used to manage SSL certificates directly and filter out bad traffic,
before redirecting it to either Synapse or NGINX

### Configuration

* **haproxy/conf/haproxy.cfg**

## NGINX

Only used to serve Let's Encrypt ACME challenges and
the **.well-known/matrix/server** file in this setup.

### Configuration

* **nginx/conf/nginx.conf**

## COTURN

Used to help VOIP users setup their firewalls in order to communicate
directly.

In this setup, COTURN uses the host network in order to avoid dealing
with Docker "port-ranges" mapping.

> Turns out that if you ask Docker to NAT ports between 49000 and 65535
> to your container, Docker will setup **one `iptables` rule PER PORT** !  
> So if you want to map ports using the 'ports' directive, you'll have
> to wait patiently for Docker to setup roughly 16000 `iptables` rules !  
> Using the Docker host avoid [this issue](https://success.docker.com/article/docker-compose-and-docker-run-hang-when-binding-a-large-port-range).

### Configuration

* **coturn/conf/turnserver.conf**

### Database

* **coturn/conf/turndb**

### Template database

The original form of **coturn/conf/turndb**

* **coturn/conf/turndb_sample**

### Check if users were added correctly

`sqlite3 coturn/data/turndb "select * from turnusers_lt"`

## PostgreSQL

### Data

Execute `docker volume inspect pgdata` and check the folder
pointed by "Mountpoint".

## Synapse

### Configuration

Main configuration files :

* **synapse/conf/homeserver.yaml**
* **synapse/conf/homeserver.d/database.yaml**
* **synapse/conf/homeserver.d/registration.yaml**
* **synapse/conf/homeserver.d/voip.yaml**


Sample configuration with comments :

* **synapse/conf/homeserver.yaml.sample**

Keys generated by Synapse. I have no idea about how this is used.

* **synapse/conf/keys**

Data (avatars, files, ...) of your server :

* **synapse/data**
