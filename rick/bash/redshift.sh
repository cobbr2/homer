# Switch Jarvis to using real Redshift and the develoment "warehouse" cluster.
#
# BusinessReporter uses a MockConnection by default in development
function redshift-dev() {
  export REDSHIFT_CONNECTION_TYPE='BusinessReporter::Redshift::Connection'
  aws-environment analytics-dev
  redshift-env warehouse uat
}

# Switch back to using the Mock
function redshift-mock() {
  export REDSHIFT_CONNECTION_TYPE='BusinessReporter::MockConnection'
}

# Set up an entire set of Redshift environment variables as used
# in warehouse or jarvis.
function redshift-env() {
  local cluster="$1"
  local user="${2:-root}"
  export REDSHIFT_PASSWORD=$(gr::redshift::credentials "${cluster}" "${user}" "$(gr::redshift::max_temp_session_time)")
  export REDSHIFT_USER="IAM:${user}"
  source <(gr::redshift::connection "${1}" env)
}

## Tunnel logins are not finished or patched into the rest of this stuff yet.
function gr::redshift::tunnel_needed() {
  cluster=$1

  case "${cluster}" in
  "stats" | "phi" ) return 0 ;;
  * )               return 1 ;;
  esac
}

function gr::redshift::tunnel_up() {
  cluster=$1

  if gr::socket::port_in_use 5439 ; then
    echo "Tunnel appears to already exist, using..." 1>&2
  else
    ssh -N -L 5439:"grnds-analytics-dev-stats.ct6witdxdwib.us-east-1.redshift.amazonaws.com":5439 brastion &
    trap 0 "kill $!"
  fi

  clip_redshift_credentials stats root
  psql -U IAM:root postgresql://localhost:5439/stats?sslmode=require
  #psql --set=sslmode=require -h localhost -p 5439 -U root stats
}

# Get a connection string or environment-settings for a specific cluster in the
# current AWS account. Currently, most environments have a `warehouse`,
# `stats`, and `claims` cluster
function gr::redshift::connection() {
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
function gr::redshift::credentials() {
  local cluster="${1}"
  local user="${2}"
  local duration="${3:-$(gr::redshift::max_temp_session_time)}"

  aws redshift get-cluster-credentials \
      --db-user "${user}" \
      --cluster-identifier "grnds-$(aws-environment)-${cluster}" \
      --duration-seconds "${duration}" |
    awk '/DbPassword/  {print $2}' |\
    sed 's;";;g'
}

# Connect via psql to a cluster in the current AWS account, as the root user
# (or one you specify). Note that it doesn't have any idea of what database you
# want to talk to, so you'll probably need to use a \c command in psql to
# switch databases.  In Warehouse, it's easier to use `rake db:enter`
function redshift() {
  local cluster="$1"
  local user="${2:-root}"
  local connection_string=$(gr::redshift::connection "${cluster}")

  export PGPASSWORD=$(gr::redshift::credentials "${cluster}" "${user}")

  psql "${connection_string}" -U "IAM:${user}"
}

# This is the max we can use. See the documentation for the
# `aws redshift get-cluster-credentials` command
function gr::redshift::max_temp_session_time() {
  echo "3600"
}
