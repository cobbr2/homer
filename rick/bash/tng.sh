
deploy_infra() {
  tng deploy infra --follow --apply --allow-delete --local-descriptors $(current_service) $(git rev-parse HEAD)
}
