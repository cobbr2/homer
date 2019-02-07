# Switch to using real Redshift
#
# BusinessReporter uses a MockConnection by default in development
function redshift_dev() {
  export REDSHIFT_CONNECTION_TYPE='BusinessReporter::Redshift::Connection'
  aws-environment analytics-dev
  redshift-env warehouse uat
}

# Switch back to using the Mock
function redshift_mock() {
  export REDSHIFT_CONNECTION_TYPE='BusinessReporter::MockConnection'
}

# Get a connection string or environment for a specific cluster in the current
# AWS account. Currently, most environments have a `warehouse`, `stats`, and
# `claims` cluster
function redshift_connection() {
  pattern="${1:?No cluster name given to find connection string for}"
  shift
  format="${1:-url}"

  aws redshift describe-clusters |
  jq '(.Clusters | .[] | { (.ClusterIdentifier): ( .DBName, .Endpoint.Address, (.Endpoint.Port | tostring) )}) | select(.[])' |
  awk '
    BEGIN { format="'"${format}"'" }
    /'"${pattern}"'/ && $2 ~ /"[0-9]*"/ { gsub(/"/,"",$2); port['"${pattern}"'] = $2; next }
    /'"${pattern}"'/ && $2 ~ /.*\..*\..*/ { gsub(/"/,"",$2); host['"${pattern}"'] = $2 ; next }
    /'"${pattern}"'/ { gsub(/"/,"",$2); dbname['"${pattern}"'] = $2 ; next }
    END {
      if (port['"${pattern}"']) {
        if ("url" == format) {
          print "postgresql://" host['"${pattern}"'] ":" port['"${pattern}"'] "/" dbname['"${pattern}"'] "?sslmode=require"
        }
        if ("env" == format) {
          print "export REDSHIFT_HOST=\"" host['"${pattern}"'] "\""
          print "export REDSHIFT_PORT=\"" port['"${pattern}"'] "\""
          print "export REDSHIFT_DBNAME=\"" dbname['"${pattern}"'] "\""
        }
      }
    }
  '
}

# Get a temporary set of credentials for a specific user in the cluster.  Note
# that the "root" user for both UAT and development warehouse clusters is
# `uat` at the moment.
function redshift_credentials() {
  local cluster="${1}"
  local user="${2}"
  local duration="${3:-3600}"

  aws redshift get-cluster-credentials \
      --db-user "${user}" \
      --cluster-identifier "grnds-$(aws-environment)-${cluster}" \
      --duration-seconds "${duration}" |\
    awk '/DbPassword/  {print $2}' |\
    sed 's;";;g'
}

# Put some temporary credentials on your clipboard. Assumes you have Rick
# Cobb's `clip` function which works on both MacOS and Linux.
function clip_redshift_credentials() {
  local cluster=${1}
  local user=${2}
  local duration=${3:-3600}

  redshift_credentials "${cluster}" "${user}" "${duration}" | clip
}

# Connect via psql to a cluster in the current AWS account, as the root user
# (or one you specify). Note that it doesn't have any idea of what database you
# want to talk to, so you'll probably need to use a \c command in psql to
# switch databases.  In Warehouse, it's easier to use `rake db:enter`
function redshift() {
  local cluster="$1"
  local user="${2:-root}"
  local connection_string=$(redshift_connection "${cluster}")

  clip_redshift_credentials "${cluster}" "${user}" "${duration}"

  echo "Password is on your clipboard"
  psql "${connection_string}" -U "IAM:${user}"
}

# This is the max we can use. See the documentation for the
# `aws redshift get-cluster-credentials` command
function redshift_max_temp_session_time() {
  echo "3600"
}

# Set up an entire set of Redshift environment variables as used
# in warehouse or Jarvis.
function redshift-env() {
  local cluster="$1"
  local user="${2:-root}"
  export REDSHIFT_PASSWORD=$(redshift_credentials "${cluster}" "${user}" "$(redshift_max_temp_session_time)")
  export REDSHIFT_USER="IAM:${user}"
  source <(redshift_connection "${1}" env)
}
