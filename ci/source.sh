#!/usr/bin/env bash

function setExpressionsDir() {
    EXPRESSIONS_DIR="${scriptdir}/.."
    if [[ ! -e ${EXPRESSIONS_DIR}/default.nix ]]; then
        echo Could not find EXPRESSIONS_DIR
        exit 1
    fi
    export EXPRESSIONS_DIR
}
export setExpressionsDir

function getInstalledLabshellFlavors () {
    compgen -c labshell_ | sort | sed  's/labshell_//g' | tr '\n' ' '
}
export getInstalledLabshellFlavors