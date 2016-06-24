
function path_split {
  echo $PATH | tr ':' '\012'
}

function path_has {
  path_split | egrep '^'"${1}"'$' >/dev/null
}

function path_push {
  if ! path_has "${1}" ; then
    if path_split | fgrep '/.rvm/' > /dev/null ; then
      rvm_paths=$(path_split | fgrep '/.rvm/')
      non_rvm_paths=$(path_split | fgrep -v '/.rvm/')
      NEW_PATH=$(echo "${rvm_paths}
${1}
${non_rvm_paths}" | tr '\012' ':')
    else
      NEW_PATH="${1}:${PATH}"
    fi
    PATH="${NEW_PATH}"
  fi
}

function path_append {
  if ! path_has "${1}" ; then
    PATH="${PATH}:${1}"
  fi
}

path_push ~/engineering/bin
for setup in ~/engineering/bash/*.sh ; do
  . $setup
done

path_push ~/bin
for setup in ~/homer/rick/bash/*.sh ; do
  . $setup
done

if [ -n "$rvm_path" ] ; then
  cd $PWD # Get the .rvm_* files read
fi
