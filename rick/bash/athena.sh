function athena() {
  # Until we get the provisioning of Athena in Terraform to conform
  # to our S3 bucket conventions:
  bucket=`aws s3 ls | awk '/aws-athena-query-results/ { print $NF }'`
  if [ -z "${bucket}" ] ;then
    echo "No results bucket found for aws-environment $AWS_ENVIRONMENT"
    return  1
  fi
  athenacli --s3-staging-dir s3://${bucket} "${@}"
}
