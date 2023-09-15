
deploy_infra() {
  tng deploy infra --follow --apply --allow-delete --local-descriptors $(current_service) $(git rev-parse HEAD)
}

alias 'deploy-infra'='deploy_infra'

export PLATFORM_API_USAGE_STYLE=light
