
honesty-login() {
  curl https://honesty.ci.grandrounds.com/docker_login.sh | bash
}

is-ipsec-up() {
  # May be able to get by with 0 associations 0 connecting, but not trying that
  # yet
  if sudo ipsec status | grep 'Security Associations' ; then
    return 0
  else
    return 1
  fi
}

honesty-development() {
  if is-ipsec-up >/dev/null; then
    echo "No dice: ipsec is running" 1>&2
    return 1
  fi
  pushd ${GR_HOME}/cargo >/dev/null
  aws-environment ci
  honesty-environment ${1:-local}
  export CARGO_DEBUG=true
  export CARGO_BRANCH=$(pwb)
  popd >/dev/null
}

honesty-kill-dockers() {
  zombies=$(docker ps | awk '/\.dkr\.ecr\./ { print $1 }')
  if [ -z "${zombies}" ] ; then
    return 0
  fi
  docker kill $zombies
}
