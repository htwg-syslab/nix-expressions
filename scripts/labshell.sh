#!/usr/bin/env bash
#
# Compatibility script for the previously used function implementation.
# The function is still active in some shells and will break without this.
unset function
exec labshell $@
