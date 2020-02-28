# About

This repository contains files to "quickly" setup a Matrix
Synapse server.  
It's not a push-button though, since Synapse configuration
is kind of a pain to setup... But in 3 commands you should
be ready to go !

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

Empty the database file and let COTURN regenerate it :

```bash
> data/coturn/db/turndb
```

* Setup a login/password combination for your TURN/STUN server.

```bash
TURN_USERNAME=username
TURN_PASSWORD=password
TURN_REALM=turn_domain_name # It's actually just a string to differentiate configurations
docker-compose run coturn turnadmin -a -b "/usr/local/var/db/turndb" -u TURN_USERNAME -p TURN_PASSWORD -r TURN_DOMAINNAME
```

### Matrix

* Create a `data/matrix` folder
* Make it Read/Write/Executable by anyone (ugh)
(TODO: Use sticky bits ?)

```bash
chmod 0777 data/matrix
```
 
* Execute the following command to generate the configuration file :

```bash
docker-compose run -e SYNAPSE_SERVER_NAME=matrix.example.com -e SYNAPSE_REPORT_STATS=no matrix generate
```

> You can use `SYNAPSE_REPORT_STATS=yes` if you want.

* Edit the configuration file **data/matrix/homeserver.yaml**, and
  replace the `turn_uris`, `turn_username`, `turn_password` and
  `database` entries to mirror your setup.  

```bash
turn_uris: ["turn:turn.example.com:3478?transport=udp", "turn:turn.example.com:3478?transport=tcp"]
turn_username: "turn_username"
turn_password: "turn_password"

database:
  database:
  name: "psycopg2"
  args:
    user: your_database_username
    password: YourDatabasePassword
    database: your_db_name
    host: postgresql
```

## Run it

* From this repo, run :

```bash
docker-compose up -d
```

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

For the moment, this result in having to 'generate' the configuration
file first (because their generators knows how to generate these
keys correctly), THEN edit it, THEN restart the server again with the
right database setup.  
But that's not all ! Turns out that in my current configuration,
synapse is started as some random user and cannot access the
/data directory... I have to execute a `chown 991:991 data/matrix`
from the host, or let everyone write into the /data folder
(`chmod o+rwx data/matrix`). I don't understand why synapse isn't
executed as root inside a Docker container and I'll have to edit
the build script.

Combine this with COTURN, which is nice when it works, but can be
a pain to debug when it doesn't due to BUFFERING LOGS ! (WHY !?)  

And you'll get *that bundle of services that look cool but you
don't want to use*, because you know how painful debugging will
be when they start behaving badly (which they'll do).

So, yeah... it's here "for the example".


