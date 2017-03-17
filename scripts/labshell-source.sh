LABSHELL_NIX_CHANNEL_COMMIT=2839b101f927be5daab7948421de00a6f6c084ae
NIX_PATH=shellpkgs=https://github.com/NixOS/nixpkgs-channels/archive/${LABSHELL_NIX_CHANNEL_COMMIT}.tar.gz:$NIX_PATH

LABSHELL_PREFETCH_COMMIT=${LABSHELL_PREFETCH_COMMIT:-master}
LABSHELL_PREFETCH_REPO=${LABSHELL_PREFETCH_REPO:-https://github.com/htwg-syslab/nix-expressions}
LABSHELL_PREFETCH_STDOUT_LOGFILE=${LABSHELL_PREFETCH_STDOUT_LOGFILE:-/var/tmp/labshell_prefetch_stdout.log}
LABSHELL_UPDATE=${LABSHELL_UPDATE:-1}

function _labshellDld() {
    umask 0000
    if $(nix-prefetch-url ${LABSHELL_PREFETCH_REPO}/archive/${LABSHELL_PREFETCH_COMMIT}.tar.gz --unpack --print-path > "${LABSHELL_PREFETCH_STDOUT_LOGFILE}.new"); then
        cat ${LABSHELL_PREFETCH_STDOUT_LOGFILE}.new > ${LABSHELL_PREFETCH_STDOUT_LOGFILE}
        rm ${LABSHELL_PREFETCH_STDOUT_LOGFILE}.new
    fi
}

function _labshellGetPath() {
    sed '2q;d' ${LABSHELL_PREFETCH_STDOUT_LOGFILE}
}

function labshell() {
    if ! [[ ${LABSHELL_UPDATE} -eq 1 || -e ${LABSHELL_PREFETCH_STDOUT_LOGFILE} ]]; then
        printf "error: update disabled and prefetch file %s not found\n" ${LABSHELL_PREFETCH_STDOUT_LOGFILE}
        exit 1
    fi
    if [[ ${LABSHELL_UPDATE} -eq 1 ]]; then
        _labshellDld
    fi
    $(_labshellGetPath)/scripts/labshell.sh $1
}
