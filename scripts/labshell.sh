#!/usr/bin/env bash
set -e
set -x

LABSHELL_SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
LABSHELL_UPDATE=${LABSHELL_UPDATE:-0}

source ${LABSHELL_SCRIPTDIR}/labshell-source.sh
NIX_SHELL_DRV=${LABSHELL_SCRIPTDIR}/../
NIX_SHELL_DRVATTR=shell_${1:-base}
exec nix-shell \
    ${NIX_SHELL_OPTS} \
    --pure \
    --argstr shDrv ${NIX_SHELL_DRV} \
    -A ${NIX_SHELL_DRVATTR} \
    ${NIX_SHELL_DRV}
