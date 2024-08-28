#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

if ! command -v go &> /dev/null; then
    echo "Error: Go is not installed." >&2
    exit 1
fi

usage() {
    echo "Usage: $0 <version>"
    echo "Example: $0 1.9.4"
    exit 1
}

if [ "$#" -ne 1 ]; then
    echo "Error: Version argument is required."
    usage
fi

version=$1
arch=$(uname -m)

build_from_source() {
    # if $version is 1.9.4-1, then $version will be 1.9.4
    version=$(echo $version | cut -d'-' -f1)
    echo "Building Packer v${version} from source for ${arch}"

    export GOPATH=$HOME/go
    export PATH=$PATH:$GOPATH/bin
    export GO111MODULE=on

    mkdir -p $GOPATH/src/github.com/hashicorp
    cd $GOPATH/src/github.com/hashicorp
    if [ ! -d "packer" ]; then
        git clone https://github.com/hashicorp/packer.git
    fi
    cd packer

    echo "Fetching the version ${version}"
    git fetch --all --tags
    git checkout tags/v${version} -b build-v${version}

    echo "Building Packer"
    make

    echo "Verifying the Packer"
    ./bin/packer version

    echo "Installing Packer"
    mv ./bin/packer /usr/local/bin/
}

# Function to install Packer using HashiCorp apt repository
install_using_apt() {
    echo "Installing Packer v${version} using a package manager for ${arch}"

    if [ "${arch}" == "x86_64" ]; then
        arch="amd64"
    fi
    curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
    echo "deb [arch=${arch}] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee -a /etc/apt/sources.list

    apt-get update
    apt-get install --no-install-recommends -y packer=${version}

    echo "Verifying the Packer"
    packer version
}

main() {
    if [ "${arch}" == "s390x" ]; then
        build_from_source
    else
        install_using_apt
    fi
}   

main $@
