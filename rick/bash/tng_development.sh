ltng ()
{
  local bin='tng'
  local cli="$IH_HOME/platform-api/build/local/cli";
  if [ -f "$cli" ]; then
      bin="$cli";
  fi;

  "$bin" --server http://localhost:8000 --timeout 120 "$@"
}

export IMAGE_BUILDER_ROOT="${IH_HOME}/image-builder"
path_append "${IMAGE_BUILDER_ROOT}/bin"
