#!/usr/bin/env bash
set -xe

msg="Hi, I taste like \${LABSHELL_FLAVOR}"
tmpscript=$(mktemp); chmod +x $tmpscript

trap "rc=$?; [[ ! -e $tmpscript ]] || rm $tmpscript; exit $rc" EXIT
trap "exit $?" ERR

cat > $tmpscript <<EOF
#!/usr/bin/env labshell
#!LABSHELL_FLAVOR=admin
#!/bin/sh -xe
echo $msg
EOF
LABSHELL_COMMAND="$tmpscript $msg" labshell

for f in ${FLAVORS}; do
    NIX_SHELL_OPTS="--command true" labshell $f
    LABSHELL_COMMAND="echo $msg" labshell $f
    LABSHELL_FLAVOR=$f LABSHELL_MODE=shell labshell -c "echo $msg"
    labshell_${f} -c "echo $msg"

    cat > $tmpscript <<EOF
#!/usr/bin/env labshell
#!LABSHELL_FLAVOR=${f}
#!/bin/sh -xe
echo $msg
EOF
    $tmpscript

    cat > $tmpscript <<EOF
#!/usr/bin/env labshell_${f}
#!/bin/sh -xe
echo $msg
EOF
    $tmpscript

    cat > $tmpscript <<EOF
#!/usr/bin/env labshell_${f}
echo $msg
EOF
    $tmpscript

done