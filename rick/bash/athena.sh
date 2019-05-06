function athena::result_bucket {
  local cache=$(aws s3 ls)
  local bucket=$(echo "${cache}" | awk '/grnds-.*athena.*results/ { print $NF }')
  if [ -z "${bucket}" ] ; then
    # Until we get the provisioning of Athena in Terraform to conform
    # to our S3 bucket conventions, also allow:
    bucket=$(echo "${cache}" | awk '/aws-athena-query-results/ { print $NF }')
  fi

  if [ -z "${bucket}" ] ; then
    echo "No results bucket found for current AWS identity $(aws sts get-caller-identity)" 1>&2
    return  1
  fi
  echo "${bucket}"
  return 0
}

# This is packaged in this file so I can drop the whole file onto
# e.g., hermes and test.
function assume-role() {
  role_arn=${1:?"Role ARN"}
  session_default="$(basename role_arn)-${USER}-$$"
  session_name=${2:-${session_default}}

  # Make sure we're not working in an already-assumed role; when
  # working with an instance, drop all 3 vars.
  unset AWS_SESSION_TOKEN
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY

  local temp_role=$(aws sts assume-role --role-arn "${role_arn}" --role-session-name "${session_name}")

  export AWS_ACCESS_KEY_ID=$(echo $temp_role | jq .Credentials.AccessKeyId | xargs)
  export AWS_SECRET_ACCESS_KEY=$(echo $temp_role | jq .Credentials.SecretAccessKey | xargs)
  export AWS_SESSION_TOKEN=$(echo $temp_role | jq .Credentials.SessionToken | xargs)
}

function athena::wait_for_result() {
  local POLL_INTERVAL=0.5
  while true ; do
    local execution=$(aws athena get-query-execution --query-execution-id "${1}")
    local state=$(echo "${execution}" | jq '.QueryExecution.Status.State' | xargs)

    case "${state}" in
      "RUNNING")
        sleep ${POLL_INTERVAL}
        continue
        ;;
      "SUCCEEDED")
        #echo "${execution}" | jq '.QueryExecution.ResultConfiguration.OutputLocation' | xargs
        return 0
        ;;
      *)
        return 1
        ;;
    esac
  done
}

# Usable without installing athenacli or creating its config file. Really
# ugly output right now
function athena_query() {
  local bucket=$(athena::result_bucket)
  if [ $? -ne 0 ] ; then
    return 1
  fi

  local execution_id=$(
    aws athena start-query-execution --query-string "${1}" --result-configuration "OutputLocation=s3://${bucket}/query-$$-${RANDOM}" |\
      jq ".QueryExecutionId" |\
      xargs
  )

  echo "execution id: ${execution_id}"

  if athena::wait_for_result ${execution_id} ; then
    aws athena get-query-results --query-execution-id "${execution_id}"
  else
    aws athena get-query-execution --query-execution-id "${execution_id}"
  fi
}

function athena() {
  bucket=$(athena::result_bucket)
  athenacli --s3-staging-dir s3://${bucket} "${@}"
}
