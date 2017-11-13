
function gr-vpn-config() {
  pushd $GR_HOME/metal >/dev/null

  old_env="${AWS_ENVIRONMENT}"
  environment=${1:-${AWS_ENVIRONMENT}}
  aws-environment ${environment}

  my_rightsubnet="$(grep "config.vpc " config/environments/$environment* |cut -f2 -d"'")/16"
  my_eipalloc=$(grep  "vpngw.eip_id" config/environments/$environment* |cut -f2 -d"'")
  my_rightip=$(aws ec2 describe-addresses --allocation-ids $my_eipalloc |jq -r '.Addresses[].PublicIp')
  cat <<EOF
right=${my_rightip}
rightsubnet=${my_rightsubnet}
rightid=${environment}
EOF

  aws-environment "${old_env}"
  popd >/dev/null
}
