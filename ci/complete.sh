#!/usr/bin/env bash
set -e

scriptdir=$(cd $(dirname $0); pwd)
source $scriptdir/source.sh

$scriptdir/install.sh
$scriptdir/test.sh
