#!/usr/bin/env nix-shell
#!nix-shell -p bashInteractive
#!nix-shell -i bash

msg="Hi, I taste like \${LABSHELL_FLAVOR_INSTANTIATED}"
tmpscript=$(mktemp); chmod +x $tmpscript

trap "rc=$?; [[ ! -e $tmpscript ]] || rm $tmpscript; exit $rc" EXIT
trap "echo Test $testnr failed; exit $?" ERR

scriptdir=$(cd $(dirname $0); pwd)
. $scriptdir/source.sh
FLAVORS="${FLAVORS:-$(getInstalledLabshellFlavors)}"

testnr=-1
function runtest() {
    (( testnr++ ))
    cat <<EOF
------------------------------------------------------------------
Test ${testnr}: $1
------------------------------------------------------------------
EOF
    ( T ) || {
    cat <<EOF
---- Test ${testnr} failed with code $?---------------------------
---- Rerunning with LABSHELL_DEBUG=1 -----------------------------
EOF
        set -x
        ( LABSHELL_DEBUG=1 T )
        rc=$?
    cat <<EOF
---- Test ${testnr} failed with code $rc -------------------------
EOF
        exit $rc
    }
}


if [[ "${RUDIMENTARY}" == "true" ]]; then
  for f in ${FLAVORS}; do
      function T() {
          ( echo "echo $msg; exit 42" | labshell $f ) || [[ $? -eq 42 ]]
      }
      runtest "labshell $f: pipe 'exit 42' to interactive shell"
  done
  exit 0
fi

function T() {
    ( echo "echo $msg; exit 42" | labshell ) || [[ $? -eq 42 ]]
}
runtest "labshell: pipe 'exit 42' to interactive shell without flavor specification"

function T() {
    cat > $tmpscript <<EOF
#!/usr/bin/env labshell
#!/bin/bash -xe
[[ \${LABSHELL_DEBUG} && \${LABSHELL_DEBUG} -eq 2 ]] || exit 43
exit 42
EOF
    LABSHELL_DEBUG=2 LABSHELL_COMMAND="$tmpscript" labshell || [[ $? -eq 42 ]]
}
runtest "labshell: set LABSHELL_DEBUG=2, must be passed through to script called in LABSHELL_COMMAND"

flavors=( ${FLAVORS} )
if [[ ${#flavors[@]} -ge 2 ]]; then
function T() {
    cat > $tmpscript <<EOF
#!/usr/bin/env labshell
#!LABSHELL_FLAVOR=${flavors[1]}
#!/bin/sh -xe
echo $msg
exit 42
EOF
    LABSHELL_COMMAND="$tmpscript $msg" labshell || [[ $? -eq 42 ]]
}
    runtest "labshell: LABSHELL_COMMAND script that uses labshell as interpreter with ${flavors[1]} flavor"
fi

for f in ${FLAVORS}; do
    function T() {
        ( echo "echo $msg; exit 42" | labshell $f ) || [[ $? -eq 42 ]]
    }
    runtest "labshell $f: pipe 'exit 42' to interactive shell"

    function T() {
        LABSHELL_COMMAND="echo $msg" labshell $f
    }
    runtest "labshell $f: LABSHELL_COMMAND displays msg"

    function T() {
        LABSHELL_FLAVOR=$f labshell -c "echo $msg"
    }
    runtest "labshell with argument to echo msg: LABSHELL_FLAVOR=$f"

    function T() {
        labshell_${f} -c "echo $msg"
    }
    runtest "labshell_$f called with echo msg"

    function T() {
        labshell_${f} -c "man --where procfs; man --where vmstat"
    }
    runtest "labshell_$f find common manpages"

    function T() {
    cat > $tmpscript <<EOF
#!/usr/bin/env labshell
#!LABSHELL_FLAVOR=${f}
#!/bin/sh -xe
echo $msg
EOF
    $tmpscript
    }
    runtest "embedded script with interp labshell with flavor $f: real_interp /bin/sh -xe; echo msg"

    function T {
    cat > $tmpscript <<EOF
#!/usr/bin/env labshell_${f}
#!/bin/sh -xe
echo $msg
EOF
    $tmpscript
    }
    runtest "embedded script with interp labshell_$f: real_interp /bin/sh -xe; echo msg"

    function T {
    cat > $tmpscript <<EOF
#!/usr/bin/env labshell_${f}
#!/usr/bin/env bash -xe
echo $msg
EOF
    $tmpscript
    }
    runtest "embedded script with interp labshell_$f: real_interp /usr/bin/env /bash -xe; echo msg"

    function T {
    cat > $tmpscript <<EOF
#!/usr/bin/env labshell_${f}
echo $msg
exit 1
EOF
    $tmpscript || [[ $? -eq 1 ]]
    }
    runtest "embedded script with interp labshell_$f: real interp missing; echo msg"
done

cat <<EOF
------------------------------------------------------------------
Tests completed successfully.
------------------------------------------------------------------
EOF
