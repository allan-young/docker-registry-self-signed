# Docker Registry Self-Signed

This project provides a few scripts to help configure a private
self-signed Docker Registry that is defined and run via
docker-compose.  A script is provided to create a deb package so the
self-signed Root Certificate can be easily installed on Debian/Ubuntu
based hosts intended to use the self-signed registry.

## Description

I've found the scripts in this project to be useful when provided a
collection of Docker hosts and a need for them to pull images from a
private self-signed Registry.  One script, _gen_config.py_, is run to
create the keys, certificates and configuration files needed to run
Docker's Registry image and the other script,
_root-cert-create-deb.sh_, is used to create an installable deb
package that can be used to install the self-signed root certificate
on each of the host computers, providing they are running a Debian
derived Linux installation such as Ubuntu.  If desired, the
installation of the self signed root certificate can be performed
manually.

Note that _gen_conf.py_ does not change your IP address configuration
or IP address name resolution.  When specifying hostnames and domains
it is up to you to make sure they resolve to the intended systems.

The basic process is to perform the following ("_gen_config.py -h_"
will display optional parameters):

    ./gen_config.py
    ./root-cert-create-deb.sh

Then use _docker-compose_ to start the Registry.

Install the self-signed Root Certificate on clients.

Start using the Registry.


### What is a Docker Registry?

The Docker documentation states "The Registry is a stateless, highly
scalable server side application that stores and lets you distribute
Docker images."

### What's the story on self-signing?

This refers to the signing of the SSL certificate used to establish a
secure connection between the client and your private Docker Registry.
The "self-signed" comes into play if you do not use a trusted
Certificate Authority (CA) to sign your certificate.  If you don't
have a CA then self-signing may be an option for you.  Those that are
security conscious will want to research potential risks of self
signing.

### Project Motivation

Searching online you can find various tutorials and descriptions of
how to manually setup a Docker Registry but gleaning the details
required to deploy a self-signed Docker Registry can be challenging.
Scripts provided in this project should hopefully reduce the pain
associated with setting up a self-signed Docker Registry.

The Python script, _gen_config.py_, is provided to generate/sign
various keys & certificates while also tweaking a suitable nginx
configuration that will be used when running the Registry via
docker-compose.  The resulting self-signed Root Certificate can be
installed on the target computers manually or, if the host is Debian
based like Ubuntu, a helper script can create a .deb package that can
be used to install the Certificate using native package installation
methods, for example dpkg.

Note that _gen_config.py_ also sets up the initial user
authentication, the corresponding _htpasswd_ file used by nginx, is
located at _nginx/auth/registry.passwd_ and an initial username and
password can be set via _gen_config.py_'s command line interface.  To
add users or otherwise manage access once deployed see the man page
and documentation for the _htpasswd_ command.

## Overview

You'd need to know this information but it may help those who are keen
to understand how this solution is put together.  We've got a number
of moving pieces in play:

A Docker Registry image, identified in the docker-compose.yml file.

An nginx image, also in docker-compose.yml, that we'll use to
handle/route Registry authentication and access.

SSL keys and certificates used for encrypted data transfer between the
Registry and client computer(s).  This includes a Root Certificate
that should be installed on your client computer(s) and another
certificate for the computer running the Registry, that certificate
needs to be signed by our Root certificate.

The _gen_config.py_ script performs the various openssl key/certificate
operations along with the nginx configuration.  docker-compose is then
used to run the Registry.

## Software Prerequisites

### Docker and docker-compose
This project assumes we are running Linux with Docker installed.

Since the Docker Registry uses Docker the computer intended to host
and run the Registry needs the appropriate Docker support installed
along with docker-compose.  For the Docker installation see:

https://docs.docker.com/engine/install/

The Docker documentation for obtaining docker-compose can be found at
[https://docs.docker.com/compose/install/](https://docs.docker.com/compose/install/)
and for Linux this basically amounts to:

    sudo curl -L "https://github.com/docker/compose/releases/download/1.25.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

### Python3

Python3 is needed for the _gen_config.py_ script that is used to
create and sign SSL keys as well as tweak the nginx configuration.

### OpenSSL

The _gen_config.py_ script uses _openssl_ for key/certificate creation
and signing.  On Ubuntu:

    sudo apt-get install -y openssl

### htpasswd

The _gen_config.py_ script uses _htpasswd_ to create the initial user
and password entry to be consumed by _nginx_.  You'll also need
_htpasswd_ installed for adding or changing user and password
information.  On Ubuntu _htpasswd_ can be installed via:

    sudo apt-get install -y apache2-utils

### fakeroot and dpkg-deb

If you are running on a Debian based distribution, like Ubuntu, and
would like to create a .deb package to install your certificate on
clients then you should also install _dpkg-deb_ and _fake-root_.

    sudo apt-get install -y fakeroot
    sudo apt-get install -y pkgbinarymangler

## Registry Server

Getting a Docker Registry up and running should be simple once you
have a sane Docker environment in place and the project files in
place.

Summary, assumes you have a working Docker / docker-compose
environment.  On the computer intended to run the Registry:

1. Get this project (clone or download and extract)
2. Run gen_config.py to generate/sign keys/certificates and nginx
   configuration
3. Install root certificate on server and client(s)
4. Start the self-signed Docker Registry
5. Confirm access and test

Starting at step 2

### Step 2: Run gen_config.py to generate/sign keys/certificates and nginx
configuration

Run _./gen_config.py -h_ to see the command line options.

You will likely want to change the default values for the _certificate
domain_ and the _registry server name_.  The _certificate domain_
refers to the domain name you use on your private network, by default
this is set to local.priv.  The _registry server name_ is the name of
the computer hosting the Registry on that network, by default this is
set to _registry_.

The script also allows you to specify an initial username and password
for client authentication.

For example, let's consider:

I decided to call my private domain _myhouse.local_ and my Registry
server name is _registry1_.  Make sure the server name with the domain
name resolves to the IP address of the computer running the Registry.
That IP resolution can be handled via your DNS configuration or
hammering details into your /etc/hosts file.  So with the above
example in mind with a properly configured network a "_ping
registry1.myhouse.local_" should show the IP address of your Registry
server and indicate the computer is reachable.

The username I want is _bob_ with password _myPassw0rd_. So for the
domain and server name along with user and password I'd perform the
following:

  $ ./gen_config.py --cert-domain myhouse.local --registry-server-name registry1 --docker-username bob --docker-password myPassw0rd

The command should generate lines of output showing various operations
including key creation and password setting.  Warning: Rerunning the
same command will overwrite the previously generated key/certificate
information.

Note that an assortment of certificate fields such as Country Codes,
State/Province Codes and Organizational Name can be populated via
_gen_config.py_ command line options.  If values are not provided on
the command line some default values will be used.

### Step 3: Install root certificate on server and client(s)

On Ubuntu and Debian based systems we can use the deb package created
by _root-cert-create-deb.sh_:

    $ sudo dpkg -i root-cert-myhouse.local_2020.07.24_all.deb 
    Selecting previously unselected package root-cert-myhouse.local.
    (Reading database ... 272281 files and directories currently installed.)
    Preparing to unpack root-cert-myhouse.local_2020.07.24_all.deb ...
    Unpacking root-cert-myhouse.local (2020.07.24) ...
    Setting up root-cert-myhouse.local (2020.07.24) ...
    Updating certificates in /etc/ssl/certs...
    1 added, 0 removed; done.
    Running hooks in /etc/ca-certificates/update.d...
    
    Adding debian:root-cert-myhouse.local.pem
    done.
    done.
    $

The Root Certificate can be installed manually if you don't what to,
or cannot, use the deb package:

    sudo cp root-cert/ /usr/local/share/ca-certificates/
    sudo update-ca-certificates

The Root Certificate installation needs to be performed on all clients
that need to access the registry.

The Docker service may need to be restarted to pick up the newly added
certificate.

    $ sudo service docker restart

### Step 4: Start the self-signed Docker Registry

The registry is started using _docker-compose up -d_ command:

    $ sudo docker-compose up -d
    Creating network "docker-registry-self-signed_default" with the default driver
    Creating docker-registry-self-signed_registry_1 ... done
    Creating docker-registry-self-signed_nginx_1    ... done
    $

### Step 5: Confirm access and test

We can use the _docker login_ command to verify our registry access.

Note that _gen_config.py_ does not manipulate you network
configuration, you'll need to ensure that your registry hostname
resolves to your intended IP address.  Be aware the login URL provided
below uses https and ends in /v2.  Recall that we are using the domain
name, registry name and user/password particulars that we provided to
the _gen_config.py_ script:

    $ sudo docker login https://registry1.myhouse.local/v2
    Username: bob
    Password: 
    WARNING! Your password will be stored unencrypted in /home/allan/.docker/config.json.
    Configure a credential helper to remove this warning. See
    https://docs.docker.com/engine/reference/commandline/login/#credentials-store
    
    Login Succeeded
    $

Now that the registry is running and we confirmed we have access lets
grab an image and put it into our repository.

We'll use the classic Docker hello-world image in our test.  The
following will pull down and run the official hello-world image:

    sudo docker run hello-world

Now we'll tag the hello-world image so that we can store our tagged
version of the image into our private repository.  In the tag we
prefix our resgistry name and domain and have also tweaked the name.

    $ sudo docker tag hello-world registry1.myhouse.local/my-hello-world:v1

Now push the newly tagged image into our registry:

    $ sudo docker push registry1.myhouse.local/my-hello-world:v1
    The push refers to repository [registry1.myhouse.local/my-hello-world]
    9c27e219663c: Pushed 
    v1: digest: sha256:90659bf80b44ce6be8234e6ff90a1ac34acbeb826903b02cfa0da11c82cbc042 size: 525
    $

We can also perform a check by pulling the image:

    $ sudo docker pull registry1.myhouse.local/my-hello-world:v1
    v1: Pulling from my-hello-world
    Digest: sha256:90659bf80b44ce6be8234e6ff90a1ac34acbeb826903b02cfa0da11c82cbc042
    Status: Image is up to date for registry1.myhouse.local/my-hello-world:v1
    registry1.myhouse.local/my-hello-world:v1
    $

Great.  We can push images into the self-signed repository and access
them via docker pull.

## License

This project is licensed under the MIT License - see the
[LICENSE.md](LICENSE.md) file for details

## References

* [Docker Engine overview](https://docs.docker.com/install/)
* [Install Docker Compose](https://docs.docker.com/compose/install/)


