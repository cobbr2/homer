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

alias service-compiler="tng params exec --service platform-api -- $IH_HOME/platform-api/build/local/service-compiler"
