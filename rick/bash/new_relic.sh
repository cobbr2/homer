function newrelic_login() {
  gpg_file_name=~/gpgs/newrelic-api-keys.gpg
  $(gpg -o - --use-agent --quiet ${gpg_file_name} | awk "/${AWS_ENVIRONMENT}:/"' { print "export TF_VAR_newrelic_api_key=" $2 }')
}
