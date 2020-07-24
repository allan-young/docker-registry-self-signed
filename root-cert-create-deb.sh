#!/bin/sh

# This file is part of the docker-registry-self-signed project, which
# is distributed under the terms of the MIT License, See the project's
# LICENSE file for details.
#
# Copyright (C) 2020 Allan Young
#
# This script is used to create a deb installation package for the
# self-signed Root certificate created by gen_config.py.  The
# resulting .deb package should be installable on platforms that
# support Debian package management.  In summary, the self-signed Root
# Certificate will be placed under /usr/local/share/ca-certificates/
# and update-ca-certificates will be run to update the hosts
# certificates.
#
#   For example:
#   # ./gen-config.py
#   # ./root-cert-create-deb.sh
#   # Package created: root-cert-local.priv_2020.06.24_all.deb
#   #
#
#   Then on the target computer needing the Root Certificate:
#   # dpkg -i root-cert-local.priv_2020.06.24_all.deb
#
# To run this deb package creation script you'll need a Linux
# installation that provides dpkg-deb and fakeroot if you want to
# create the package as a non-root user, Debian derived distributions,
# such as Ubunut, should work.

SCRIPT_VERSION="0.1"
PACKAGE_VERSION=$(date +'%Y.%m.%d')
PACKAGE_MAINTAINER="Not Specified"

# By default the temporary build directory will be removed after the
# package has been created.
TMP_BUILD_DIR="tmp-build"
INSTALL_DIR=${TMP_BUILD_DIR}/usr/local/share/ca-certificates

# Source directory/file(s) for the Debian package build process.
DEBIAN_SOURCE_DIR="debian"
POSTINST_SCRIPT=${DEBIAN_SOURCE_DIR}/postinst
POSTRM_SCRIPT=${DEBIAN_SOURCE_DIR}/postrm

SKIP_PACKAGE_BUILD=0
SKIP_REMOVE_TMP_BUILD_DIR=0

SCRIPT_UID=$(id -u)

usage()
{
    cat << EOF
usage: root-cert-create-deb.sh -v package_version [-m \"package_maintainer\"]
                        [-c cert_file] [-s] [-k]
       root-cert-create-deb.sh --script_version

Used to create a Debian style deb package for installing a self-signed
Root Certificate.

Where:
  -v The version number for the package created; default is the
     numeric date YYYY.MM.DD when the deb file was created.
  -m The Maintainer entry field for the package, should be the
     maintainer's name along with email address, for example "John Doe
     <jdoe@someemail.com>"; default is "Not Specified".
  -c The Root Certificate file; default is *.crt in the root-cert
     directory.
  -s Skip the underlying package build step, perform only the steps
     prior to the actual package creation.  Can be useful when
     debugging this script.
  -k Do not remove the temporary build directory after the package has
     been built, useful when debugging this script.
  --script-version Displays this script's version and exits.
EOF
}

root_fakeroot_check()
{
    if [ "$SCRIPT_UID" -ne 0 ] && [ ! -e /usr/bin/fakeroot ]; then

	cat <<EOF
This script requires 'fakeroot' when run as a non-root user. Either
run as root or install fakeroot: "sudo apt-get install fakeroot
EOF
	exit 1
    fi
}

dpkg_deb_check()
{
    # shellcheck disable=SC2230 
    if CHECK="$(which dpkg-debx 2>&1)"; then
	cat <<EOF
Command 'dpkg-deb' not found, this script requires 'dpkg-deb' for
package creation.  Install using apt: "sudo apt-get install dpkg-deb"
EOF
	echo "$CHECK"
	exit 1
    fi
}

prep_tmp_build_dir()
{
    # Remove previous remnants, if they exist.
    if [ -d "$TMP_BUILD_DIR" ]; then
	rm -rf "$TMP_BUILD_DIR"
    fi

    if [ ! -d "$INSTALL_DIR" ]; then
	mkdir -p "$INSTALL_DIR"
    fi
}

cp_root_cert()
{
    if ! MKDIR_OUT=$(mkdir -p "$DEST_DIR" 2>&1); then
	echo "Error making build destination directory \"$DEST_DIR\":"
	echo "$MKDIR_OUT"
	exit 1
    fi
    
    if ! CP_OUT=$(cp -v "$CERT_PATH" "$DEST_DIR/" 2>&1); then
	echo "Error copying Root Certificate \"$CERT_PATH\":"
	echo "$CP_OUT"
	exit 1
    fi
}

prep_debian_dir()
{
    # Need to calculate and provide our size when building the
    # package.
    PACKAGE_SIZE=$(du -skc ${TMP_BUILD_DIR} | tail -n1 | awk '{print $1}')

    # Create the standard DEBIAN directory for package configuration
    # files.
    mkdir -p ${TMP_BUILD_DIR}/DEBIAN

    cp ${POSTINST_SCRIPT} ${TMP_BUILD_DIR}/DEBIAN
    cp ${POSTRM_SCRIPT} ${TMP_BUILD_DIR}/DEBIAN

    # Generate the Debian control file.
    PACKAGE_DEPENDS=""

    cat >"${TMP_BUILD_DIR}/DEBIAN/control" <<EOF
Package: ${PACKAGE_NAME}
Version: ${PACKAGE_VERSION}
Architecture: all
Maintainer: ${PACKAGE_MAINTAINER}
Installed-Size: ${PACKAGE_SIZE}
Depends: ${PACKAGE_DEPENDS}
Recommends:
Section: Miscellaneous
Priority: Optional
Multi-Arch: foreign
Description: Self-signed Root Certificate for private Docker registry (${DOMAIN})
 This package contains a self-signed Root Certificate intended for a
 private Docker registry with domain ${DOMAIN}.
EOF
}

build_deb_package()
{
    if [ "$SCRIPT_UID" -eq 0 ]; then
	# Running as root, directly invoke dpkg-deb.
	RESULT_OUT=$(dpkg-deb --build ${TMP_BUILD_DIR}/ .)
	RC="$?"
	if [ "$RC" -ne 0 ]; then
	    echo "Failed to create package:"
	    echo "$RESULT_OUT"
	    exit 1
	fi
    else
	# Not running as root, use fakeroot.
	RESULT_OUT=$(fakeroot -- dpkg-deb --build ${TMP_BUILD_DIR}/ .)
	RC="$?"
	if [ "$RC" -ne 0 ]; then
	    echo "Failed to create package:"
	    echo "$RESULT_OUT"
	    exit 1
	fi
    fi
    echo "Package created: ${PACKAGE_NAME}_${PACKAGE_VERSION}_all.deb"
}

# Command line processing.
while [ $# -gt 0 ]; do
    case "$1" in
	-v)
	    shift
	    if [ $# -eq 0 ]; then
		echo "Missing argument for -v, package version."
		exit 1
	    fi
	    PACKAGE_VERSION="$1"
	    ;;
	-m)
	    shift
	    if [ $# -eq 0 ]; then
		echo "Missing argument for parameter -m, maintainer name."
		exit 1
	    fi
	    PACKAGE_MAINTAINER="$1"
	    ;;
	-c)
	    shift
	    if [ $# -eq 0 ]; then
		echo "Missing argument for parameter -c, Root Certificate file."
		exit 1
	    fi
	    CERT_PATH="$1"
	    if [ ! -f "$CERT_PATH" ]; then
		echo "Could not find specified certificate file: $CERT_PATH"
		exit 1
	    fi
	    ;;
	-s)
	    SKIP_PACKAGE_BUILD=1
	    ;;
	-k)
	    SKIP_REMOVE_TMP_BUILD_DIR=1
	    ;;
	--script-version)
	    echo "Version: $SCRIPT_VERSION"
	    exit 0
	    ;;
	-h|--help)
	    usage
	    exit 0
    esac
    shift
done

if [ -z "$CERT_PATH" ]; then
    CERT_FILENAME=$(basename root-cert/*.crt)
    CERT_PATH="root-cert/$CERT_FILENAME"
else
    CERT_FILENAME=$(basename "$CERT_PATH")
fi

PACKAGE_NAME=$(echo "$CERT_FILENAME" | sed 's/\.crt$//')
DEST_DIR="$INSTALL_DIR/$PACKAGE_NAME"

# Extract the certificate domain from the package name, i.e. drop the
# root-cert- prefix.
DOMAIN="${PACKAGE_NAME#root-cert-}"

root_fakeroot_check
dpkg_deb_check
prep_tmp_build_dir
cp_root_cert
prep_debian_dir

if [ "$SKIP_PACKAGE_BUILD" -eq 0 ]; then
    build_deb_package

    if [ "$SKIP_REMOVE_TMP_BUILD_DIR" -eq 0 ]; then
	if [ -d "$TMP_BUILD_DIR" ]; then
	    rm -rf "$TMP_BUILD_DIR"
	fi
    fi
fi

exit 0
