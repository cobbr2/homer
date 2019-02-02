function pg_floyd() {
  source <(gpg --quiet -d ~/.aws-creds/rcobb-floyd.txt.gpg 2>/dev/null)
  echo $FLOYD_URL | sed 's;^.*:\(.*\)@.*$;\1;' | clip
  psql -h floyd.analytics.grandrounds.com production
}

function pg_glasshouse() {
  source <(gpg --quiet -d ~/.aws-creds/rcobb-glasshouse.txt.gpg 2>/dev/null)
  echo $GLASSHOUSE_URL | sed 's;^.*:\(.*\)@.*$;\1;' | clip
  psql -h grnds-prod-redshift.cdtahy5ttivj.us-east-1.redshift.amazonaws.com -p 5439 prod
}

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

function redshift_credentials() {
  local cluster="${1}"
  local user="${2}"
  local duration="${3:-3600}"

  aws redshift get-cluster-credentials --db-user "${user}" --cluster-identifier "grnds-$(aws-environment)-${cluster}" --duration-seconds "${duration}" |\
    awk '/DbPassword/  {print $2}' |\
    sed 's;";;g'
}

function clip_redshift_credentials() {
  local cluster=${1}
  local user=${2}
  local duration=${3:-3600}

  redshift_credentials "${cluster}" "${user}" "${duration}" | clip
}

function redshift() {
  local cluster="$1"
  local user="${2:-root}"
  connection_string=$(redshift_connection "${cluster}")
  clip_redshift_credentials "${cluster}" "${user}" "${duration}"

  echo "Password is on your clipboard"
  psql "${connection_string}" -U "IAM:${user}"
}

function redshift_max_temp_session_time() {
  echo "3600"
}

function redshift-env() {
  local cluster="$1"
  local user="${2:-root}"
  export REDSHIFT_PASSWORD=$(redshift_credentials "${cluster}" "${user}" "$(redshift_max_temp_session_time)")
  export REDSHIFT_USER="IAM:${user}"
  source <(redshift_connection "${1}" env)
}

function port_in_use() {
  netstat -an | grep -q ":${1:-5439}"
}

# Not working as of 2/1/2019; acting as if the brastion side of tunnel is failing (tunnel comes up, but connection refused)
function pg_bronze_stats() {
  # See .ssh/config for `brastion` settings
  if port_in_use 5439 ; then
    echo "Tunnel appears to already exist, using..." 1>&2
  else
    ssh -N -L 5439:"grnds-analytics-dev-stats.ct6witdxdwib.us-east-1.redshift.amazonaws.com":5439 brastion &
  fi
  clip_redshift_credentials stats root
  psql -U IAM:root postgresql://localhost:5439/stats?sslmode=require
  #psql --set=sslmode=require -h localhost -p 5439 -U root stats
}

function pg_brickhouse() {
  aws-environment analytics-production
  clip_redshift_credentials stats
  psql "postgresql://grnds-analytics-production-stats.cmljpoykglsq.us-east-1.redshift.amazonaws.com:5439/stats?sslmode=require" -U IAM:root
}
