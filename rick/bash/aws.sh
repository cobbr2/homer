#!/usr/bin/env sh

export AWS_ENVIRONMENT_BETA=1
export AWS_DEFAULT_ROLE=developer

if gpg_agent_working && [ -z "$AWS_ENVIRONMENT" ] ; then
  dev-environment --no-tty
fi

alias s3='aws s3'

alias 'aws-refresh'='aws-environment "${AWS_ENVIRONMENT}"'

ec2-ip() {
  field=3
  usage='ec2-ip [ --name | -n ] service'
  while [ $# -gt 0 ] ; do
    case $1 in
    -n | --name) field=2 ;;
    -*) echo "$usage" ; exit 2 ;;
    *) break ;;
    esac
    shift
  done
  # Add '-2' at the end of the patterns so we find only `stone`, not
  # `stone-worker`
  gr-list-instances "${1}" | awk -F'|' "/${1}-2/"' { value=$'"${field}"';gsub(/ /,"",value); print value ; exit }'
}

ec2-sh() {
  destination="${1}"
  shift
  ssh $(ec2-ip "$destination") "${@}"
}
