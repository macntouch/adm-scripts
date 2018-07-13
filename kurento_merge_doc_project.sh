#!/usr/bin/env bash

#/
#/ Generate and commit source files for Read The Docs.
#/
#/ Arguments:
#/
#/   None.
#/

# ------------ Shell setup ------------

# Shell options for strict error checking
set -o errexit -o errtrace -o pipefail -o nounset

# Logging functions
# These disable and re-enable debug mode (only if it was already set)
# Source: https://superuser.com/a/1338887/922762
shopt -s expand_aliases  # This trick requires enabling aliases in Bash
BASENAME="$(basename "$0")"  # Complete file name
echo_and_restore() {
    echo "[${BASENAME}] $(cat -)"
    case "$flags" in (*x*) set -x ; esac
}
alias log='({ flags="$-"; set +x; } 2>/dev/null; echo_and_restore) <<<'

# Trap functions
on_error() { ERROR=1; }
trap on_error ERR
on_exit() {
    (( ${ERROR-${?}} )) && log "ERROR" || log "SUCCESS"
    log "==================== END ===================="
}
trap on_exit EXIT

# Print help message
usage() { grep '^#/' "$0" | cut -c 4-; exit 0; }
expr match "${1-}" '^\(-h\|--help\)$' >/dev/null && usage

# Enable debug mode
set -o xtrace

log "#################### BEGIN ####################"



# ------------ Script start ------------

# Internal variables
RTD_PROJECT="${KURENTO_PROJECT}-readthedocs"

kurento_clone_repo.sh "$KURENTO_PROJECT" \
|| { log "ERROR Command failed: kurento_clone_repo $KURENTO_PROJECT"; exit 1; }

{
    pushd "$KURENTO_PROJECT"

    if [ -z "${MAVEN_SETTINGS:+x}" ]; then
        cp Makefile Makefile.ci
    else
        sed -e "s@mvn@mvn --settings $MAVEN_SETTINGS@g" Makefile > Makefile.ci
    fi

    make --file="Makefile.ci" ci-readthedocs \
    || { log "ERROR Command failed: make ci-readthedocs"; exit 1; }

    rm Makefile.ci

    popd  # $KURENTO_PROJECT
}

log "Command: kurento_check_version (tagging enabled)"
kurento_check_version.sh true \
|| { log "ERROR Command failed: kurento_check_version (tagging enabled)"; exit 1; }

kurento_clone_repo.sh "$RTD_PROJECT" \
|| { log "ERROR Command failed: kurento_clone_repo $RTD_PROJECT"; exit 1; }

rm -rf "${RTD_PROJECT:?}"/*
cp -a "${KURENTO_PROJECT:?}"/* "${RTD_PROJECT:?}"/

log "Commit and push changes to repo: $RTD_PROJECT"

{
    pushd "$RTD_PROJECT"

    git status
    git diff-index --quiet HEAD || {
      git add --all .
      log "TODO REVIEW: global GIT_COMMIT: $GIT_COMMIT"
      git commit -m "Code autogenerated from Kurento/${KURENTO_PROJECT}@${GIT_COMMIT}"
      git push origin master \
      || { log "ERROR Command failed: git push ($RTD_PROJECT)"; exit 1; }
    }

    export CHECK_SUBMODULES="no"
    log "Command: kurento_check_version (tagging enabled)"
    kurento_check_version.sh true \
    || { log "ERROR Command failed: kurento_check_version (tagging enabled)"; exit 1; }

    popd  # $RTD_PROJECT
}
