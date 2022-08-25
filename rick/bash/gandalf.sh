#!/usr/bin/env bash

# All of this is Quick & Dirty for testing with IAM Users rather than
# federated ones.

function aws_logout() {
  unset $(env | grep AWS_ | awk -F= '{print $1}')
}

function gandalf::account() {
  echo 264181272549
}

function gandalf::role() {
  echo stone
}

session_tags=""
function gandalf::session_tags() {
  echo $session_tags
}

function gandalf::assume_role() {
  role_arn="arn:aws:iam::$(gandalf::account):role/$(gandalf::role)"
  session_name="$(gandalf::role)-$(date +%Y%m%dT%H%M%S%Z)"
  duration=3600

  creds=$(aws sts assume-role --role-arn "${role_arn}" --role-session-name "${session_name}" --duration-seconds "${duration}" $(gandalf::session_tags))

  echo "${creds}" >_foobar
  if [ $? -eq 0 ] ; then
    export AWS_ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' <<<${creds})
    export AWS_SECRET_ACCESS_KEY=$(jq -r '.Credentials.SecretAccessKey' <<<${creds})
    export AWS_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' <<<${creds})
  fi
}

function gandalf() {
  while [ $# -gt 0 ] ; do
    case $1 in
      "-s") session_tags="Key=access-service,Value=stone" ;;
    esac
    shift
  done

  aws_logout
  gpgenv gandalf-access
  gandalf::assume_role
}

# Oh, I love this boilerplate just because it's *so* awful:
# See https://stackoverflow.com/questions/2683279/how-to-detect-if-a-script-is-being-sourced/14706745#14706745
sourced=0
if [ -n "$ZSH_EVAL_CONTEXT" ]; then
  case $ZSH_EVAL_CONTEXT in *:file) sourced=1;; esac
elif [ -n "$KSH_VERSION" ]; then
  [ "$(cd $(dirname -- $0) && pwd -P)/$(basename -- $0)" != "$(cd $(dirname -- ${.sh.file}) && pwd -P)/$(basename -- ${.sh.file})" ] && sourced=1
elif [ -n "$BASH_VERSION" ]; then
  (return 0 2>/dev/null) && sourced=1
else # All other shells: examine $0 for known shell binary filenames
  # Detects `sh` and `dash`; add additional shell filenames as needed.
  case ${0##*/} in sh|dash) sourced=1;; esac
fi

if [ $sourced == 0 ] ; then
  gandalf ${@:+"${@}"}
fi
