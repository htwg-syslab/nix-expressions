#!/usr/bin/env bash
set -e
if [[ ${LABSHELL_DEBUG} -gt 0 ]]; then
    set -x
fi

STDERR="$(readlink /proc/self/fd/2)"
LABSHELL_CONFIG_DIR=${HOME}/.config/labshell
[[ -d ${LABSHELL_CONFIG_DIR} ]] || mkdir -p ${LABSHELL_CONFIG_DIR}
LOG="${LABSHELL_CONFIG_DIR}"/labshell.sh.$$.log

LABSHELL_SHELL="${LABSHELL_SHELL:-bash}"
LABSHELL_SCRIPTNAME="$(basename $0 | sed 's,\..*$,,')"
LABSHELL_SCRIPT="$0"

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

# Arguments from this index will be passed to the nested shell
SCRIPT_ARGINDEX=1

# Possibly called as a script interpreter
IN_SHBANG=0
if [[ -x "$1" && -n "$(sed '1q;d' $1 | grep ${LABSHELL_SCRIPTNAME})" ]]; then
    #!/path/to/labshell
    IN_SHBANG=1
elif [[ -x "$2" && -n "$(sed '1q;d' $2 | grep ${LABSHELL_SCRIPTNAME})" ]]; then
    #!/other/path /path/to/labshell
    IN_SHBANG=1
    SCRIPT_ARGINDEX=2
fi

if [[ ${IN_SHBANG} -eq 1 ]]; then
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
        esac
        (( i++ ))
    done < <(sed -n '1d;/^#!LABSHELL.*=.*/s,#!,,p;' ${SCRIPT})
    REAL_INTERP_LINE="$(sed "${i}q;d" ${SCRIPT})"
    if [[ ${REAL_INTERP_LINE} =~ ^\#\! ]]; then
        REAL_INTERP=${REAL_INTERP_LINE/\#\!/}
    else
        echo No secondary interpreter provided in ${SCRIPT}. Defaulting to ${REAL_INTERP}
        REAL_INTERP="${LABSHELL_SHELL}"
    fi
fi
REAL_INTERP=${REAL_INTERP:-${LABSHELL_SHELL}}
# Assert that we have set the REAL_INTERP
[[ -n ${REAL_INTERP} ]]

LABSHELL_FLAVOR="${LABSHELL_FLAVOR:-${LABSHELL_FLAVOR_INSTANTIATED}}"
if [[ ! "${LABSHELL_FLAVOR}" ]]; then
    if [[ "${IN_SHBANG}" -eq 0 && "${@:1:1}" ]]; then
        if [[ ! "${@:2}" ]]; then
            LABSHELL_FLAVOR="${LABSHELL_FLAVOR:-${1}}"
            FLAVOR_IN_ARG1=1
        else
            errecho The flavor could not be evaluated.
            errecho Defaulting to 'base' and passing all arguments along.
            LABSHELL_FLAVOR="base"
        fi
    fi
fi

if [[ ! ${LABSHELL_FLAVOR} ]]; then
    errecho The flavor could not be evaluated.
    errecho Defaulting to 'base' and passing all arguments along.
    LABSHELL_FLAVOR="base"
elif ! [[ "${LABSHELL_FLAVOR}" =~ ^[[:alnum:]]+$ ]]; then
    errecho LABSHELL_FLAVOR must be set and must only contain letters
    exit 1
fi

cat <<EOF
Spawning shell with settings:
    flavor: '${LABSHELL_FLAVOR}'
    #!-Interpreter: ${IN_SHBANG}
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
        '-A' "labshells.${LABSHELL_FLAVOR}"
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
                nix_instantiate_cmd+=(
                    "--arg" "labshellExpressionsUpdateFromLocal" "true"
                )
                echo Using expressions on filesystem ${LABSHELL_EXPRESSIONS_REMOTE_URL}
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


if [[ "${NIX_SHELL_OPTS}" ]]; then
    nix_shell_opts=()
    for opt in ${NIX_SHELL_OPTS}; do
        case ${opt} in
            --command)
                errecho NIX_SHELL_OPTS may not contain ${opt}
                ;;
            *)
                nix_shell_opts=( "${opt}" )
                ;;
        esac
    done
fi

nix_shell_cmd=(
    "nix-shell"
    "${LABSHELL_INSTANTIATED_DRV}"
    ${nix_shell_opts}
    "--no-build-output"
    "--pure"
    "--command"
)

# Pass the shellhook through to the other shell if it can handle it
rc=$(mktemp)
cat > $rc <<-EOF
rm $rc
source \$shellHookFile
echo Environment initialized!
EOF
# --init-file must be the first argument
real_interp_array=( ${REAL_INTERP} )
real_interp_array+=()
REAL_INTERP="${real_interp_array[@]:0:1} --init-file $rc ${real_interp_array[@]:1}"
[[ "${REAL_INTERP}" =~ init-file ]]

#nix_shell_cmd+=("$(for a in "${@:$(( SCRIPT_ARGINDEX+1 ))}"; do printf " %q" "${a}"; done)")

if [[ ${LABSHELL_COMMAND} ]]; then
    nix_shell_cmd_command=(
        "${REAL_INTERP} -c $(printf "%q" "${LABSHELL_COMMAND}")"
    )
elif [[ ${FLAVOR_IN_ARG1} -eq 1 ]]; then
    nix_shell_cmd_command=(
        "${REAL_INTERP}"
    )
else
    nix_shell_cmd_command=(
        "${REAL_INTERP} $(for a in "${@:$(( SCRIPT_ARGINDEX ))}"; do printf " %q" "${a}"; done)"
    )
fi

if [[ ${LABSHELL_DEBUG} -eq 0 ]]; then
    set +x
    exec 2>> "${STDERR}"
fi
rm -f ${LOG}

# Assert the command argument is not empty
[[ "${nix_shell_cmd_command[@]}" ]]

nix_shell_cmd+=(
    "${nix_shell_cmd_command[@]}"
)

exec "${nix_shell_cmd[@]}"