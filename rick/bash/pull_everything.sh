#!/bin/bash

pull_everything() {
  for git in ${GR_HOME}/*/.git ; do
    dir=$(dirname $git)

    pushd ${dir} >/dev/null
    sed 's/^ *//' <<FOO
      ---------------
      $(pwd)
      ---------------
FOO
    git pull
    popd >/dev/null
  done
}

forin() {
  dirs=$1
  shift
  for dir in $dirs ; do
    if [ ! -d ${dir} ] ; then
      echo "Not a directory: ${dir}"
      continue
    fi
    pushd ${dir} >/dev/null
    sed 's/^ *//' <<FOO
      ---------------
      $(pwd)
      ---------------
FOO
    eval $@
    popd >/dev/null
  done
}
# See also `devdirs` in ricks_aliases
