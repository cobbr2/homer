structurizr() {
  local port=${1:-8080}
  if [ ! -f workspace.dsl -a ! -f workspace.json ] ; then
    echo "Get you to a structurizr directory" 1>&2
    return 1
  fi

  echo "Starting on localhost port ${port}"
  docker run -it --rm -p "${port}":8080 -v "${PWD}":/usr/local/structurizr structurizr/lite
}
