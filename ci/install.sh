#!/usr/bin/env bash
set -e

nix_env_cmd=(
  "nix-env"
  "--fallback"
  "--file" "${EXPRESSIONS_DIR:-$PWD}"
  "--max-jobs" "2"
  "--cores" "0"
  "-iA" "labshell"
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

for f in ${FLAVORS}; do
  nix_env_cmd+=( "labshells.${f}" )
done

set -x
"${nix_env_cmd[@]}" "--no-build-output" || "${nix_env_cmd[@]}"
