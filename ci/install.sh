#!/usr/bin/env bash
set -e

scriptdir=$(cd $(dirname $0); pwd)
. $scriptdir/source.sh
setExpressionsDir

nix_env_cmd=(
  "nix-env"
  "--fallback"
  "--file" "${EXPRESSIONS_DIR:-$PWD}"
  "--max-jobs" "2"
  "--cores" "0"
  "--no-build-output"
)

REMOTE_REV="${REMOTE_REV:-${TRAVIS_PULL_REQUEST_BRANCH:-${TRAVIS_BRANCH}}}"
if [[ "${REMOTE_REV}" ]]; then
  nix_env_cmd+=(
    "--argstr" "labshellExpressionsRemoteRev" "${REMOTE_REV}"
  )
else
  nix_env_cmd+=(
    "--arg" "labshellExpressionsUpdateFromLocal" "true"
  )
fi

nix_env_cmd+=(
  "-iA"
)

# labshell application
"${nix_env_cmd[@]}" "labshell" || "${nix_env_cmd[@]}"

# labshell flavored wrappers
if [[ ${FLAVORS} ]]; then
  for f in ${FLAVORS}; do
    nix_env_cmd+=( "labshellsUnstable.${f}" )
  done
else
    nix_env_cmd+=( "labshellsStable" )
fi
"${nix_env_cmd[@]}" || "${nix_env_cmd[@]}"