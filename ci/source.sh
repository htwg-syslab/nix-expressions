#/usr/bin/env  bash

function expressiondir(){ export EXPRESSIONS_DIR=$(cd $(dirname $0); pwd)/..;  }
if [[ $_ != $0 ]]; then
    expressiondir $_
else
    expressiondir $0
fi

export FLAVORS="${FLAVORS:-base bsys admin code sysoHW0 sysoHW1 sysoHW2 rtos}"
