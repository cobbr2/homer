# Still in use while we decomm Jarvis and then do something about TP

function railslts() {
  case $AWS_ENVIRONMENT in
  uat | production  ) ;;
  * ) echo "Must have UAT or production in environment"
  esac
  export BUNDLE_GEMS__RAILSLTS__COM=$(tng params get --service tp bundle-gems-railstls-com)
  export LAUNCHDARKLY_TOKEN=dummy
}
