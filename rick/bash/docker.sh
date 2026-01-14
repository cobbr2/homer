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

# Fix this to use a real stack someday, then add push_ops & pop_ops back into
# does_image_exist so that has some utility outside of checking for main branch
# builds
push_ops() {
  case "${AWS_ENVIRONMENT}" in
  operations )
    return 0 ;;
  * )
    PUSHED_ACCOUNT="${AWS_ENVIRONMENT}"
    PUSHED_ROLE="${AWS_ENVIRONMENT_ROLE}"
    USE_LEGACY_AWS_ENVIRONMENT=true aws-environment operations platform # Requires platform perms at moment
    return 0
    ;;
  esac
}

pop_ops() {
  if [ -z "${PUSHED_ACCOUNT}" ] ; then
    echo "Popped all" 1>&2
    return -1
  fi
  aws-environment "${PUSHED_ACCOUNT}" "${PUSHED_ROLE}"
  unset PUSHED_ACCOUNT
  unset PUSHED_ROLE
}

_does_image_exist() {
  if [[ $# -lt 2 ]]; then
      echo "Usage: $( basename $0 ) <repository-name> <image-tag>"
      return 1
  fi

  # push_ops
  IMAGE_META="$( aws ecr describe-images --repository-name=$1 --image-ids=imageTag=$2 2> /dev/null )"
  local image_status=$?
  # pop_ops

  if [[ $image_status == 0 ]]; then
      return 0
  else
      echo "$1:$2 not found"
      return 1
  fi
}

# Now that this uses `gh pr checks`, it doesn't need (can't use) the sha to
# check... so this really is private to the `wait_for_build` /
# `release_latest` stuff which make sure that we're in the right repository
# and the latest sha is pushed.
#
# Design decision to let these low-level routines print their own status is
# beginning to smell bad.
#
# Bug: if there are required checks that haven't reported a status yet, gh pr
# checks exits 0
_branch_head_is_built() {
  local branch="${1:-$(pwb)}"
  gh pr checks --watch "${branch}"
}

wait_for_build() {
  local branch="${1:-$(pwb)}"
  local start_time=$(date +%s)

  if [ "${branch}" == "$(main_branch)" ] ; then
    # Can't use gh pr since no pr; have to check for image directly
    # using operations account.
    service="$(current_service)"
    image_tag="$(git rev-parse HEAD)"
    push_ops
    until _does_image_exist "${service}" "${image_tag}" ; do
      local current_time=$(date +%s)
      cat 1>&2 <<-STILL_WAITING
	Main branch build still does not exist. $(($current_time - $start_time))s
	STILL_WAITING
      sleep 10
    done
    pop_ops
    return 0
  fi

  until _branch_head_is_built "${branch}" ; do
    local current_time=$(date +%s)
    cat 1>&2 <<-STILL_WAITING
	Waiting for checks to succeed. $(($current_time - $start_time))s
	STILL_WAITING
    sleep 10
  done
}

deployment_status() {
  deployment="${1:?'deployment id'}"
  tng deploy status "${deployment}" | tee /dev/tty | awk '$1 ~ /'"${deployment}"'/ { print $2 }'
}

wait_for_deploy() {
  deployment="${1:?'deployment id'}"
  while [[ $(deployment_status "${deployment}") =~ Running|Pending ]] ; do
    sleep 10
  done
}

log_deployment_and_wait() {
  deployment="${1:?'deployment id'}"

  # Still doesn't stop, since when we see END OF LOGS, tng deploy has stopped
  # sending output, so there's nothing to break the pipe.
  tng deploy logs "${deployment}" --follow | sed '/END OF LOGS/q'
}

validate_pushed_sha() {
  pushed="${1}"
  head=$(git rev-parse HEAD)
  if [ "$pushed" != "$head" ] ; then
    cat 1>&2 <<-USE_THE_REAL_COMMAND
	Your latest known origin SHA is not your local HEAD. Use
	  tng deploy run ${service} ${pushed}
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

  tng deploy run $service $pushed --follow
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

# Intended for following live logs, not deployment, since tng deploy logs --follow works for those.
tng-log-follow-all () {
  # Needs work to manage job control
  local service=${1:-$(current_service)}
  local pods=$(gr service status ${service} --json | jq '."pod-status"[].name' | tr -d '"' | grep -v deploy)
  for pod in ${pods} ; do
    stdbuf -oL -eL tng service logs ${service} ${pod} --follow | sed -u "s/^/${pod}: /" &
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

  tng service debug ${service} "${reason}" -d3600
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
