#!/usr/bin/env python3

# This file is part of the docker-registry-self-signed project, which
# is distributed under the terms of the MIT License, See the project's
# LICENSE file for details.
#
# Copyright (C) 2020 Allan Young

"""Script to help with creating the configuration needed to run a
Docker self-signed registry container."""

import argparse
import subprocess
import sys

ROOT_DIR = "root-cert"
SSL_DIR = "nginx/ssl"
HTPASSWD_FILE = "nginx/auth/registry.passwd"


def gen_keys_and_certs(country_code, state_prov, company, domain, server_name):
    """Generate Root key and Root certificate along with the server key,
    certificate signing request, and self-signed certificate."""

    root_name = "root-cert-%s" % domain
    root_key = "%s/%s.key" % (ROOT_DIR, root_name)
    root_crt = "%s/%s.crt" % (ROOT_DIR, root_name)

    # Create a personal/private Root key.
    ret = subprocess.call(["openssl", "genrsa", "-out", root_key, "4096"])
    if ret != 0:
        print("Root key creation failed, ret=%d" % ret)
        sys.exit(1)

    # Generate our personal/private Root certificate.
    ret = subprocess.call(["openssl", "req", "-x509", "-new", "-nodes",
                           "-key", root_key, "-days", "2000", "-out",
                           root_crt, "-subj", "/C=%s/ST=%s/O=%s/CN=%s" %
                           (country_code, state_prov, company, domain)])
    if ret != 0:
        print("Root certificate creation failed, ret=%d" % ret)
        sys.exit(1)

    # Generate server key.
    server_key = "%s/%s.key" % (SSL_DIR, server_name)
    server_csr = "%s/%s.csr" % (SSL_DIR, server_name)
    server_crt = "%s/%s.crt" % (SSL_DIR, server_name)
    ret = subprocess.call(["openssl", "genrsa", "-out", server_key, "4096"])
    if ret != 0:
        print("Server key creation failed, ret=%d" % ret)
        sys.exit(1)

    # Now create the certificate signing request.
    ret = subprocess.call(["openssl", "req", "-new", "-key", server_key,
                           "-out", server_csr, "-nodes", "-subj",
                           "/C=%s/ST=%s/O=%s/CN=%s" %
                           (country_code, state_prov, company, server_name)])
    if ret != 0:
        print("Server certificate signing request creation failed, "
              "ret=%d" % ret)
        sys.exit(1)

    # Now to self-sign our certificate request.  We use the Root
    # Certificate we created at the start and sign the certificate
    # request, the result is the self-signed certificate for our
    # server.
    ret = subprocess.call(["openssl", "x509", "-req", "-in", server_csr,
                           "-CA", root_crt, "-CAkey", root_key,
                           "-CAcreateserial", "-out", server_crt, "-days",
                           "2000"])
    if ret != 0:
        print("Server certificate creation failed, ret=%d" % ret)
        sys.exit(1)


def tweak_nginx_conf(server_full_name):
    """Tweak the conf.d/registry.conf file."""

    server_key = "%s.key" % server_full_name
    server_crt = "%s.crt" % server_full_name

    with open("conf/registry.conf.template") as file_obj:
        lines = file_obj.readlines()

        with open("nginx/conf.d/registry.conf", "w") as write_file_obj:
            for line in lines:
                if line.find("__SERVER_NAME__") > 0:
                    line = line.replace("__SERVER_NAME__", server_full_name)
                elif line.find("__SERVER_CRT__") > 0:
                    line = line.replace("__SERVER_CRT__", server_crt)
                elif line.find("__SERVER_KEY__") > 0:
                    line = line.replace("__SERVER_KEY__", server_key)

                write_file_obj.write(line)


def gen_htpasswd(username, password):
    """Generate htpassword file with provided username and password."""
    ret = subprocess.call(["htpasswd", "-bcB", HTPASSWD_FILE, username,
                           password])
    if ret != 0:
        print("Error generating htpasswd file. ret=%d" % ret)
        sys.exit(1)


def main():
    """The main program."""
    parser = argparse.ArgumentParser(description="Utility to generate "
                                     "a self-signed Docker registry "
                                     "configuration")
    parser.add_argument('--docker-username', metavar="username",
                        default="docker", help=("the initial username for "
                                                "registry authentication; "
                                                "default is \"docker\""))
    parser.add_argument('--docker-password', metavar="password",
                        default="passw0rd", help=("the initial password for "
                                                  "registry authentication; "
                                                  "default is \"passw0rd\""))
    parser.add_argument('--cert-country-code', metavar="cert_cc",
                        default="CA", help=("the 2 letter certificate "
                                            "Country Code; default is CA"))
    parser.add_argument('--cert-state-prov', metavar="cert_state_prov",
                        default="ON", help=("the 2 letter certificate State "
                                            "or Province Code; default is ON"))
    parser.add_argument('--cert-company', metavar="cert_company",
                        default="NA", help=("the certificate Company entry; "
                                            "default is NA"))
    parser.add_argument('--cert-domain', metavar="cert_domain",
                        default="local.priv", help=("the certificate domain; "
                                                    "default is local.priv"))
    parser.add_argument('--registry-server-name', metavar="server_name",
                        default="registry", help=("the name for the resistry "
                                                  "server; default is "
                                                  "registry"))

    args = parser.parse_args()
    server_full_name = "%s.%s" % (args.registry_server_name, args.cert_domain)
    gen_keys_and_certs(args.cert_country_code, args.cert_state_prov,
                       args.cert_company, args.cert_domain, server_full_name)

    tweak_nginx_conf(server_full_name)
    gen_htpasswd(args.docker_username, args.docker_password)


if __name__ == '__main__':
    main()
#
# sudo mkdir /usr/local/share/ca-certificates/
# sudo cp devdockerCA.crt /usr/local/share/ca-certificates/docker-dev-cert
# sudo update-ca-certificates
