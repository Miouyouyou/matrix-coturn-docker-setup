# About

This repository contains files to "quickly" setup a Matrix
Synapse server.  

Note that more complex setups can be done using
[Ansible](https://github.com/atb00ker/ansible-matrix-synapse)

# TODO

* Test the whole thing correctly

* Add HAProxy and redirect requests to matrix.example.com towards
  the Matrix server, while handling SSL queries from HAProxy.

* References the origins of the build files (author, repo, ...).

# Usage

## First configuration

### Postgres

* Edit **env/postgres.env** and setup the credentials
  you would like to use for this server instance.

> The PostgreSQL instance should NOT be accessible
> from the outside though, unless you understand
> what you're doing.

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

### COTURN

* If you want to use SSL or NAT, have a look at **coturn/conf/turnserver.conf**

### Matrix

* Edit the **docker-compose.yaml** file
* Redefine the following variables

```yaml
      - SYNAPSE_SERVER_NAME=NameOfYourMatrixServer
      - SYNAPSE_SERVER_ADDRESS=https://matrix.yourdomain.com
      - SYNAPSE_REPORT_STATS=yes # Can be set to "no"
      - SYNAPSE_DATABASE_BACKEND=postgresql # The backend name : postgresql or sqlite
      - SYNAPSE_POSTGRES_DBADDR=postgresql # The network alias we provided to our postgresql server
      # PostgreSQL configuration is inherited from the postgres.env env_file
      - SYNAPSE_VOIP_TURN_MAIN_URL=turn:turn.yourdomain.com:3478?transport=udp
      # Can be empty ( SYNAPSE_VOIP_TURN_USERNAME= )
      - SYNAPSE_VOIP_TURN_USERNAME=turn_username
      # Can be empty if your SYNAPSE_VOIP_TURN_USERNAME is set to an empty string
      - SYNAPSE_VOIP_TURN_PASSWORD=turn_password
```

## Run it

* From this repo, run :

```bash
docker-compose up -d
```

### Add users

#### To your TURN server

TURN is used to force users wanting to do direct VOIP to punch
a hole through their firewalls, and setup their NAT correctly.
This remove the complexity of VOIP communications, without
requiring a middleman server (who could record the entire
session).

If `SYNAPSE_VOIP_TURN_USERNAME` is not set to an empty string in
the matrix configuration part, you should the user right now
(else CoTURN will reject the authentication request).

```bash
docker-compose run coturn turnadmin -a -b "/srv/coturn/turndb" -u turn_username -p turn_password -r turn.yourdomain.com
```

#### To your Synapse server

TODO

### View the logs

You can then use `docker-compose logs` to get the logs of every
units at once, or :
* `docker-compose logs --last=50 -f matrix` to follow Synapse logs
* `docker-compose logs --last=5 -f coturn` to follow COTURN logs
* `docker-compose logs -f postgresql` to follow PostgreSQL logs

## Shut it down

* From this repo, run :

```bash
docker-compose down
```

Notes
-----

Synapse has really WEIRD (to say the least) design choices
when it comes to configuration files. They put some important
cryptographic keys INSIDE THE MAIN CONFIGURATION FILE !

To me, it's as insane as putting your SSH keys inside sshd_config.

I'll see about patching this and sending a PR.

Still, they seem to support configuration file directories...
Though I don't know if they documented it.  
I also took a look at their configuration generation scripts and...
I'm starting to think that they need a way to define the configuration
and its grammar, and have the code generated through this definition.  
Here they're doing the reverse and it seems to have the effect of
having tons of undocumented settings, coupled with configuration
generating tools that aren't on par...

Combine this with COTURN, which is nice when it works, but can be
a pain to debug when it doesn't due to BUFFERING LOGS ! (WHY !?)  

And you'll get *that bundle of services that look cool but you
don't want to use*, because you know how painful debugging will
be when they start behaving badly (which they'll do).

So, yeah... it's here "for the example".


