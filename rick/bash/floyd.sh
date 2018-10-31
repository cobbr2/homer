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

# Did not complete. Idea was to use this to find the redshift to connect to.
function redshift() {
  set -x
  local name=$1
  # Gave up on getting the strings I wanted, so awk & grep it is.
  #jq '(.Clusters | .[] | { (.ClusterIdentifier): ( .Endpoint.Address,  + ":" + ( .Endpoint.Port | tostring) )}) | select(.[])' |
  local connection_string=$(
    aws redshift describe-clusters |
    jq '(.Clusters | .[] | { (.ClusterIdentifier): ( .DBName, .Endpoint.Address, (.Endpoint.Port | tostring) )}) | select(.[])' |
    awk "$name"
  )
  set +x
}

function clip_redshift_credentials() {
set -xv
  aws redshift get-cluster-credentials --db-user root --cluster-identifier grnds-$(aws-environment)-${1:-stats} --duration-seconds ${2:-3600} |\
    awk '/DbPassword/  {print $2}' |\
    sed 's;";;g' |\
    clip
set +xv
}

function port_in_use() {
  netstat -an | grep -q ":${1:-5439}"
}

function pq_bronze_stats() {
  # See .ssh/config for `brastion` settings
  if port_in_use 5439 ; then
    echo "Tunnel appears to already exist, using..." 1>&2
  else
    ssh -N -L 5439:"grnds-analytics-dev-stats.ct6witdxdwib.us-east-1.redshift.amazonaws.com":5439 brastion &
  fi
  clip_redshift_credentials stats
  psql -U IAM:root postgresql://localhost:5439/stats?sslmode=require
  #psql --set=sslmode=require -h localhost -p 5439 -U root stats
}

function pq_brickhouse() {
  aws-environment analytics-production
  clip_redshift_credentials stats
  psql "postgresql://grnds-analytics-production-stats.cmljpoykglsq.us-east-1.redshift.amazonaws.com:5439/stats?sslmode=require" -U IAM:root
}
