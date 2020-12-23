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

aws-region() {
  if [ -z "${AWS_REGION}" ] ; then
    export AWS_REGION=us-east-1
  fi
  echo "$AWS_REGION"
}

operations-aws-account-id() {
  echo 311088406905
}

aws-iam-in-group() {
  group=${1:-"grnds-catalog-enduser-production-red"}
  aws iam   get-account-authorization-details --filter User |\
        jq '.["UserDetailList"] | map(select(.GroupList | contains(["'"${group}"'"])) | .UserName )'
}
