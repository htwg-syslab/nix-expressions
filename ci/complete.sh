#!/usr/bin/env bash
set -xe

scriptdir=$(cd $(dirname $0); pwd)
source $scriptdir/source.sh

$scriptdir/install.sh
$scriptdir/test.sh
