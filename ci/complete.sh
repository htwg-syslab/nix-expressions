#!/usr/bin/env bash
set -e

scriptdir=$(cd $(dirname $0); pwd)
source $scriptdir/source.sh

(
    echo Running dummy background job to prevent CI from killing this script.
    while true; do
        sleep 60
        echo $0 is still working...
    done
) &
# Don't leave any children behind
trap "for j in `jobs -p`; do kill -9 \$j; done" EXIT

$scriptdir/install.sh
$scriptdir/test.sh
