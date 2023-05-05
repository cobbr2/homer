ltng ()
{
  local bin='tng'
  local cli="$IH_HOME/platform-api/build/local/cli";
  if [ -f "$cli" ]; then
      bin="$cli";
  fi;

  local server=''
  if nc -w 0 localhost 8000 ; then
    server="--server http://localhost:8000"
  else
    echo "using ${AWS_ENVIRONMENT} server" 1>&2
  fi

  "$bin" ${server} --timeout 120 "$@"
}

export IMAGE_BUILDER_ROOT="${IH_HOME}/image-builder"
path_append "${IMAGE_BUILDER_ROOT}/bin"
