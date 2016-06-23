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
