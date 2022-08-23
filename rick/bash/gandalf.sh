
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

function gandalf::session_tags() {
  echo "--tags Key=access-service,Value=stone"
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
  aws_logout
  gpgenv gandalf-access
  gandalf::assume_role
}
