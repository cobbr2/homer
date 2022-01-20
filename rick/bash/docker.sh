docker-login() {
  aws ecr get-login-password --region $(aws-region) |\
    docker login \
      --username AWS \
      --password-stdin $(operations-aws-account-id).dkr.ecr.$(aws-region).amazonaws.com
}

# This would be a lot cleaner if we cleaned up our Dockerfile conventions
docker-build () {
  github-token-auth
  # Don't vary this too much: many tng Docker layers will build on every change
  ref="${GR_USERNAME}-laptop-local"
  if [ -z "${RAILS_ENV}" ] ; then
    echo "Defaulting RAILS_ENV to 'development'" 1>&2
    RAILS_ENV=development
  fi
  docker build \
    --build-arg GITHUB_USER="$GITHUB_USER" \
    --build-arg GITHUB_TOKEN="$GITHUB_TOKEN" \
    --build-arg GITHUB_AUTH_TOKEN="$GITHUB_TOKEN" \
    --build-arg RAILS_ENV="$RAILS_ENV" \
    --build-arg VCS_REF="${ref}" \
    "${@}"
}

tng-build () {
  docker-build --tag $(current_service) -f docker/Dockerfile .
}

dev-build () {
  docker-build --tag $(current_service)-dev --target dev -f docker/Dockerfile .
}

og-build () {
  docker-build -f Dockerfile .
}

current_service() {
  basename $(git rev-parse --show-toplevel)
}

is_built_yet() {
  local repository="$1"
  local sha="$2"
  aws ecr batch-get-image --registry-id 311088406905 --repository-name "${repository}"  --image-ids imageTag="${sha}" |\
    jq -e '.failures as $failures | ($failures | length == 0)' 1>/dev/null
}

wait_for_build() {
  local service="${1:-$(current_service)}"
  local sha="${2:-$(git rev-parse HEAD)}"
  local start_time=$(date +%s)


  while ! is_built_yet "${service}" "${sha}" ; do
    local current_time=$(date +%s)
    cat 1>&2 <<-STILL_WAITING
	SHA ${sha} has not shown up in the ${service} ECR repository yet. $(($current_time - $start_time))s
	STILL_WAITING
    sleep 10
  done
}

deployment_status() {
  deployment="${1:?'deployment id'}"
  gr deploy status "${deployment}" | tee /dev/tty | awk '$1 ~ /'"${deployment}"'/ { print $2 }'
}

wait_for_deploy() {
  deployment="${1:?'deployment id'}"
  while [ $(deployment_status "${deployment}") == 'Running' ] ; do
    sleep 10
  done
}

log_deployment_and_wait() {
  deployment="${1:?'deployment id'}"

  # Still doesn't stop, since when we see END OF LOGS, gr deploy has stopped
  # sending output, so there's nothing to break the pipe.
  gr deploy logs "${deployment}" --follow | sed '/END OF LOGS/q'
}

deploy-latest() {
  service=${1:-$(current_service)}
  pushed=$(git rev-parse origin/$(pwb))
  head=$(git rev-parse HEAD)
  if [ "$pushed" != "$head" ] ; then
    cat 1>&2 <<-USE_THE_REAL_COMMAND
	Your latest known origin SHA is not your local HEAD. Use
	  gr deploy run ${service} ${pushed}
	to deploy it if that's what you want. Otherwise, push!
	USE_THE_REAL_COMMAND
    return 1
  fi

  start_time=`date +%s`

  wait_for_build "${service}" "${pushed}"

  echo "====================== DEPLOYING ${service} ${pushed} ===================================="

  deployment=$(gr deploy run $service $pushed | tee /dev/tty | sed -n '/Deployment ID: /s/Deployment ID: //p')

  wait_for_deploy "${deployment}"

  end_time=`date +%s`

  echo "Total time (seconds): $(($end_time - $start_time))"
}

# For `tim` at the moment.
docker-local () {
  port_map=${1:-"10004:10004"}
  tag=$(git rev-parse HEAD)
  repo=$(current_service)
  set -x
  docker run \
    -p "${port_map}" \
    -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
    -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
    -it \
    311088406905.dkr.ecr.us-east-1.amazonaws.com/${repo}:${tag} \
    /bin/bash
  set +x
}

# Intended for following live logs, not deployment, since gr deploy logs --follow works for those.
tng-log-follow-all () {
  # Needs work to manage job control
  local service=${1:-$(current_service)}
  local pods=$(gr service status ${service} --json | jq '."pod-status"[].name' | tr -d '"' | grep -v deploy)
  for pod in ${pods} ; do
    stdbuf -oL -eL gr service logs ${service} ${pod} --follow | sed -u "s/^/${pod}: /" &
  done
}

killbg () {
  local JOBS="$(jobs -p)"
  if [ -n "${JOBS}" ]; then
      kill -KILL ${JOBS}
  fi
}

current_story () {
  story=$(expr "$(pwb)" : "[^/]*/\([^/]*\)")
  if [ -z "${story}" ] ; then
    echo "Can't infer story from current branch $(pwb)" 1>&2
    return 1
  fi
  echo "${story}"
}

service_debug() {
  local service=${1:-$(current_service)}
  local reason=$(current_story)

  gr service debug ${service} "${reason}" -d3600
}

lgr() {
  ${GR_HOME}/platform-api/bin/grctl --server=http://localhost:8000 "$@"
}

docker-rm-zombies() {
  old_exited_containers=$(docker ps -a | awk '/ago *Exited/ { print $1 }')
  if [ -z "${old_exited_containers}" ] ; then
    return 0
  fi
  docker rm $old_exited_containers
}
