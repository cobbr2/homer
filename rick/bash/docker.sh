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

does_image_exist() {
  if [[ $# -lt 2 ]]; then
      echo "Usage: $( basename $0 ) <repository-name> <image-tag>"
      return 1
  fi

  IMAGE_META="$( aws ecr describe-images --repository-name=$1 --image-ids=imageTag=$2 2> /dev/null )"

  if [[ $? == 0 ]]; then
      return 0
  else
      echo "$1:$2 not found"
      return 1
  fi
}

# Now that this uses `gh pr checks`, it doesn't need (can't use) the sha to
# check... so this really is private to the `wait_for_build` /
# `release_lateest` stuff which make sure that we're in the right repository
# and the latest sha is pushed.
#
# Design decision to let these low-level routines print their own status is
# beginning to smell bad.
#
# Bug: if there are required checks that haven't reported a status yet, gh pr
# checks exits 0
branch_head_is_built() {
  local branch="${1:-$(pwb)}"
  gh pr checks --watch "${branch}"
}

# Can't use gh pr since no pr; not implemented yet, should check
# for image existence
main_branch_is_built() {
  aws ecr
}

wait_for_build() {
  local branch="${1:-$(pwb)}"
  local start_time=$(date +%s)

  until branch_head_is_built "${branch}" ; do
    local current_time=$(date +%s)
    cat 1>&2 <<-STILL_WAITING
	Branch ${branch} is BROKEN (you should finish fixing wait_for_build). $(($current_time - $start_time))s
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
  while [[ $(deployment_status "${deployment}") =~ Running|Pending ]] ; do
    sleep 10
  done
}

log_deployment_and_wait() {
  deployment="${1:?'deployment id'}"

  # Still doesn't stop, since when we see END OF LOGS, gr deploy has stopped
  # sending output, so there's nothing to break the pipe.
  gr deploy logs "${deployment}" --follow | sed '/END OF LOGS/q'
}

validate_pushed_sha() {
  pushed="${1}"
  head=$(git rev-parse HEAD)
  if [ "$pushed" != "$head" ] ; then
    cat 1>&2 <<-USE_THE_REAL_COMMAND
	Your latest known origin SHA is not your local HEAD. Use
	  gr deploy run ${service} ${pushed}
	to deploy the latest origin commit if that's what you want. Otherwise, push!
	USE_THE_REAL_COMMAND
    return 1
  fi
  return 0
}

deploy-latest() {
  service=${1:-$(current_service)}
  branch=${2:-$(pwb)}

  pushed=$(git rev-parse origin/${branch})
  if ! validate_pushed_sha "${pushed}" ; then
    return 1
  fi

  start_time=`date +%s`

  wait_for_build "${branch}"

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
