#!/usr/bin/env bash
set -e
set -x

SCRIPTPATH="$(cd "$(dirname "$0")" && pwd)"
source $SCRIPTPATH/local-source.sh
NIX_SHELL_DRV=$SCRIPTPATH/../
NIX_SHELL_DRVATTR=shell_${1:-base}
[ -z "$1" ] || shift
nix-shell \
    "$@" \
    --pure \
    --argstr shDrv ${NIX_SHELL_DRV} \
    -A ${NIX_SHELL_DRVATTR} \
    ${NIX_SHELL_DRV}