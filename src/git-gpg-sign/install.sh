#!/bin/bash
set -e

echo "Activating feature 'git-gpg-sign'"

VERSION=${VERSION:-"latest"}
ARCHITECTURE="amd64"

if [ "$(dpkg --print-architecture)" ==  "arm64" ]; then
    ARCHITECTURE="arm64"
fi

# make sure gpg is installed 
sudo apt install -y gpg
if [ "$(which gpg)" == "" ]; then
    echo "Failed to install gpg"
    exit 1
fi
KEYS=$(gpg --list-secret-keys --keyid-format LONG)

# make sure we have at least one secret key
if [ ! -z "${GPG_PUBLIC_KEY}" ]; then
    # if the gpg var is filled, see if its a full key or an id. try it as a key
    # if there are no spaces, it is probably an id
    if [[ "${GPG_PUBLIC_KEY}" == *" "* ]]; then
        echo "Importing gpg key"
        echo "${GPG_PUBLIC_KEY}" | gpg --import
        if [ $? -ne 0 ]; then
            echo "Failed to import gpg key"
        else
            # now we know which key to sign with, so we can set the git config
            # look through "KEYS" for the key we just imported
            KEY_ID=$(echo "${KEYS}" | grep "${GPG_PUBLIC_KEY}" | cut -d "/" -f 2 | cut -d " " -f 1)
        fi
    else
        echo "Importing gpg key with id ${GPG_PUBLIC_KEY}"
        gpg --keyserver keyserver.ubuntu.com --recv-keys "${GPG_PUBLIC_KEY}"
        KEY_ID="${GPG_PUBLIC_KEY}"
    fi
else
    # if the gpg var is not filled, see if we have a key already
    if [ -z "${KEYS}" ]; then
        echo "No gpg key found, please set GPG_PUBLIC_KEY"
        exit 1
    else
        # look through "KEYS" for the first key
        KEY_ID=$(echo "${KEYS}" | grep -m 1 "sec" | cut -d "/" -f 2 | cut -d " " -f 1)
    fi
fi

# If KEY_ID is still empty, exit with an error
if [ -z "${KEY_ID}" ]; then
    echo "Failed to set KEY_ID"
    exit 1
fi

# Configure git
git config --global commit.gpgsign true
git config --global tag.gpgsign true
git config --global user.signingkey "${KEY_ID}"
git config --global gpg.program gpg
