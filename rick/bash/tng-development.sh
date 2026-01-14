# Good enough for pure server work, but codegen is cli side.
ltng ()
{
  local cli="$IH_HOME/platform-api/build/local/cli";
  if [ ! -x "$cli" ] ; then
    echo "using normal (not platform-api) tng client" 1>&2
    cli='tng'
  fi

  local server=''
  if nc -w 0 localhost 8000 ; then
    server="--server http://localhost:8000"
  else
    echo "using ${AWS_ENVIRONMENT} server" 1>&2
  fi

  "$cli" ${server} --timeout 120 "$@"
}

# Set up for making sure *everything* uses local or remote.
tng-version () {
  if [ -z "${1}" ] ; then
    case `which tng` in
      "${IH_HOME}/bin/tng" )
        echo "local"
        ;;
      *)
        echo "remote"
        ;;
    esac
    return 0
  fi
  requested_version="${1:-deployed}"
  case $requested_version in
  deployed | remote)
    echo "Removing symlink to locally built version..."
    rm -f ${IH_HOME}/bin/tng
    unset PLATFORM_API_ADDR
    unset PLATFORM_API_GRPC_ADDR
    ;;
  local)
    echo "Symlinking tng to locally built version..."
    ln -s "$IH_HOME/platform-api/build/clients/tngctl.darwin.arm64" ${IH_HOME}/bin/tng 2>/dev/null
    export PLATFORM_API_ADDR=http://localhost:8000
    export PLATFORM_API_GRPC_ADDR=http://localhost:8001
    path_force ${IH_HOME}/bin

    if ! nc -w 0 localhost 8000 ; then
      echo "Remember to start your local server!" 1>&2
    fi
    ;;
  *)
    echo "Invalid version: $requested_version, must be 'deployed' or 'local'"
    return 1
    ;;
  esac
  hash -r
}

export IMAGE_BUILDER_ROOT="${IH_HOME}/image-builder"
path_append "${IMAGE_BUILDER_ROOT}/bin"

alias service-compiler="tng params exec --service platform-api  --fs local -- $IH_HOME/platform-api/build/local/service-compiler"

# Assumes your platform-map & platform-api are good enough
tng_get_infra() {
  local tar=false
  local service

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--tar)
        tar=true
        shift
        ;;
      -h|--help)
        cat <<EOF
Usage: tng_get_infra [OPTIONS]

Compiles and extracts infrastructure configuration for the current service.

OPTIONS:
  -t, --tar    Save output as a tar file instead of extracting to tf/ directory
  -h, --help   Display this help message

DESCRIPTION:
  This function must be run from a service's platform directory containing
  infrastructure.yaml and serviceConfig.yaml files.

  By default, it extracts the compiled infrastructure to a 'tf/' directory.
  With the --tar option, it saves the output as '_<service>_tf.tgz'.

EXAMPLES:
  tng_get_infra          # Extract to tf/ directory
  tng_get_infra --tar    # Save as tar file
EOF
        return 0
        ;;
      -*)
        echo "Error: Unknown option: $1" >&2
        echo "Use -h or --help for usage information" >&2
        return 1
        ;;
      *)
        echo "Error: Unexpected argument: $1" >&2
        echo "Use -h or --help for usage information" >&2
        return 1
        ;;
    esac
  done

  # Validate prerequisites
  if [ ! -f infrastructure.yaml ]; then
    echo "Error: Must be in the service's platform directory (infrastructure.yaml not found)" >&2
    return 1
  fi

  if [ ! -f serviceConfig.yaml ]; then
    echo "Error: serviceConfig.yaml not found" >&2
    return 1
  fi

  # Create tf directory if needed (when not using tar mode)
  if ! $tar; then
    if [ ! -d tf ]; then
      mkdir tf
    fi
  fi

  # Extract service name
  service="$(sed -E -ne '/^(app|service_name):/s/^(app|service_name): *//p' serviceConfig.yaml)"

  if [ -z "$service" ]; then
    echo "Error: Could not extract service name from serviceConfig.yaml" >&2
    return 1
  fi

  # Compile and process infrastructure
  service-compiler infra "${PWD}" "$(git rev-parse HEAD)" --service "${service}" | (
    if $tar; then
      cat >"_${service}_tf.tgz"
      echo "Infrastructure saved to _${service}_tf.tgz"
    else
      cd tf
      tar -xz
      echo "Infrastructure extracted to tf/"
    fi
  )
}
alias tng-get-infra=tng_get_infra

tng_tf_pod() {
  echo "You may have to copy your id_rsa file into the pod as well" 1>&2
  "${IH_HOME}/kore/bin/run-image" -r platform-terraformer -n deploy -i platform-api-deploy
}
alias tng-tf-pod=tng_tf_pod
