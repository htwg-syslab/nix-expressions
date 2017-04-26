#!/usr/bin/env bash
set -e
if [[ ${LABSHELL_DEBUG} -gt 0 ]]; then
    set -x
fi

STDERR="$(readlink /proc/self/fd/2)"
LABSHELL_CONFIG_DIR=${HOME}/.config/labshell
[[ -d ${LABSHELL_CONFIG_DIR} ]] || mkdir -p ${LABSHELL_CONFIG_DIR}
LOG="${LABSHELL_CONFIG_DIR}"/labshell.sh.$$.log

LABSHELL_SCRIPTNAME="$(basename $0 | sed 's,\..*$,,')"
LABSHELL_SCRIPT="$0"
LABSHELL_FLAVOR="${LABSHELL_FLAVOR:-base}"
LABSHELL_MODE="${LABSHELL_MODE:-interactive}"

function errecho() {
    echo $@ >&2
}

function exit_handler() {
    set +x
    exec 2>> "${STDERR}"

    if [[ -e "${LOG}" ]]; then
        cat << EOF
----------- ERROR OUTPUT BEGINNING
$(cat "${LOG}")
----------- ERROR OUTPUT END

Something went wrong on in ${LABSHELL_SCRIPT} ${2}
Please file an issue and include the output from above.
EOF
        rm "${LOG}"
    fi
    exit "${1}"
}
if [[ ! ${LABSHELL_DEBUG} -gt 0 ]]; then
    trap 'exit_handler $?' EXIT INT QUIT TERM HUP
    trap 'exit_handler $? ${LINENO}' ERR
    exec 2>> "${LOG}"
fi
set -x

# Evaluate the flavor
# Possibly called as a script interpreter
if [[ -x "$1" && -n "$(sed '1q;d' $1 | grep ${LABSHELL_SCRIPTNAME})" ]]; then
    #!/path/to/labshell
    SCRIPT_ARGINDEX=1
elif [[ -x "$2" && -n "$(sed '1q;d' $2 | grep ${LABSHELL_SCRIPTNAME})" ]]; then
    #!/other/path /path/to/labshell
    SCRIPT_ARGINDEX=2
fi

case ${SCRIPT_ARGINDEX} in
1|2)
    LABSHELL_MODE=shell
    SCRIPT="${!SCRIPT_ARGINDEX}"
    # Script could look like this:
    #!/other/path labshell
    #!labshell FLAVOR
    #!/real/interpreter
    i=2
    while read -r line; do
        case $line in
        LABSHELL_FLAVOR*)
            eval ${line}
            ;;
        *) echo Unknown option in ${SCRIPT}:${i}: ${line}
            ;;
        esac;
        (( i++ ))
    done < <(sed -n '1d;/^#!LABSHELL.*=.*/s,#!,,p;' ${SCRIPT})
    REAL_INTERP_LINE="$(sed "${i}q;d" ${SCRIPT})"
    if [[ ! ${REAL_INTERP_LINE} =~ ^\#\! ]]; then
        echo No secondary interpreter provided in ${SCRIPT}. Defaulting to 'bash'
        REAL_INTERP="bash"
    else
        REAL_INTERP=${REAL_INTERP_LINE/\#\!/}
    fi
    ;;
*)
    case ${LABSHELL_MODE} in
        interactive)
            LABSHELL_FLAVOR="${1:-${LABSHELL_FLAVOR}}"
            ;;
        shell)
            ;;
        *)
            errecho Unknown LABSHELL_MODE=${LABSHELL_MODE}
            exit 1
            ;;
    esac
    # Fallback to bash to execute any commands
    REAL_INTERP=${REAL_INTERP:-bash}
    ;;
esac

# Assert that we have set the REAL_INTERP
[[ -n ${REAL_INTERP} ]]

cat <<EOF
Spawning '${LABSHELL_FLAVOR}' shell in '${LABSHELL_MODE}' mode.
Please wait...
EOF

LABSHELL_INSTANTIATED_DRV="${LABSHELL_CONFIG_DIR}"/"${LABSHELL_FLAVOR}".drv

LABSHELL_UPDATE=${LABSHELL_UPDATE:-1}
if [[ ! $(stat -L ${LABSHELL_INSTANTIATED_DRV}) || ${LABSHELL_UPDATE} -gt 0 ]]; then
    LABSHELL_INSTANTIATE=1
    nix_instantiate_cmd=(
        "nix-instantiate"
        "--add-root" "${LABSHELL_INSTANTIATED_DRV}"
        "--indirect"
        '-A' "shell_${LABSHELL_FLAVOR}"
    )
    LABSHELL_INSTANTIATE_FROM="${LABSHELL_EXPRESSIONS_LOCAL}"

    if [[ ${LABSHELL_UPDATE} -gt 0 ]]; then
        if [[ -z "${LABSHELL_EXPRESSIONS_REMOTE_URL}" ]]; then
            errecho LABSHELL_EXPRESSIONS_REMOTE_URL not set but LABSHELL_UPDATE=${LABSHELL_UPDATE} requested.
        else
            nix_instantiate_cmd+=(
                '--argstr' 'LABSHELL_EXPRESSIONS_REMOTE_URL' "${LABSHELL_EXPRESSIONS_REMOTE_URL}"
            )

            if [[ "${LABSHELL_EXPRESSIONS_REMOTE_URL}" =~ ^/.* ]]; then
                LABSHELL_INSTANTIATE_FROM="${LABSHELL_EXPRESSIONS_REMOTE_URL}"
                echo Using expressions from ${LABSHELL_EXPRESSIONS_REMOTE_URL}
            else
                echo Downloading expressions from ${LABSHELL_EXPRESSIONS_REMOTE_URL}
                nix_prefetch_cmd+=(
                    "nix-prefetch-url"
                    "--unpack"
                    "--print-path"
                    "${LABSHELL_EXPRESSIONS_REMOTE_URL}"
                )
                LABSHELL_INSTANTIATE_FROM=$("${nix_prefetch_cmd[@]}" | tail -n1)
            fi
        fi
    fi

    [[ -n ${LABSHELL_INSTANTIATE_FROM} ]]

    # Instantiate, this will update the drv link
    ${nix_instantiate_cmd[@]} ${LABSHELL_INSTANTIATE_FROM}
fi

nix_shell_cmd=(
    "nix-shell"
    "${LABSHELL_INSTANTIATED_DRV}"
    "--no-build-output"
    "--pure"
)

if [[ "${SCRIPT}" ]]; then
    nix_shell_cmd+=("--command")
    nix_shell_cmd+=("${REAL_INTERP} ${SCRIPT} $(for a in "${@:$(( SCRIPT_ARGINDEX+1 ))}"; do printf " %q" "${a}"; done)")
elif [[ "${NIX_SHELL_OPTS}" ]]; then
    for opt in ${NIX_SHELL_OPTS}; do
        nix_shell_cmd+=( "${opt}" )
    done
elif [[ "${LABSHELL_MODE}" == "shell" ]]; then
    nix_shell_cmd+=("--command")

    # Pass the shellhook through to the other shell
    if [[ ${REAL_INTERP} =~ (env |/|^)(sh|bash) ]]; then
        rc=$(mktemp)
        cat > $rc <<EOF
        rm $rc
        source \$shellHookFile
        echo Environment initialized!
EOF
        REAL_INTERP="${REAL_INTERP} --init-file $rc"
    fi
    nix_shell_cmd+=("exec ${REAL_INTERP} $(for a in "${@:$(( SCRIPT_ARGINDEX+1 ))}"; do printf " %q" "${a}"; done)")
elif [[ ${LABSHELL_COMMAND} ]]; then
    nix_shell_cmd+=("--command")
    nix_shell_cmd+=("${REAL_INTERP} -c $(printf "%q" "${LABSHELL_COMMAND}")")
fi

if [[ ${LABSHELL_DEBUG} -eq 0 ]]; then
    set +x
    exec 2>> "${STDERR}"
fi
rm -f ${LOG}
exec "${nix_shell_cmd[@]}"
