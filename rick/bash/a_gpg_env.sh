function gpgenv  {
  $(gpg -o - --use-agent -q ${1:?gpg_file_name})
}

function gpg_agent_working {
  # *doesn't* work at the gnome startup world ("can't open /dev/tty"),
  # at the moment. So ...
  case $(tty) in
  /dev/pts/* ) return 0 ;;
  * ) return 1 ;;
  esac
}

function load_keys() {
  key_pattern='.'
  files=*.gpg

  case $# in
  0)    ;;
  1)    files=$1 ; shift ;;
  *)    key_pattern=$1 ; shift; files=$* ;;
  esac

  export $(gpg --use-agent -o - $files 2>/dev/null | sed -n -e 's/#.*$//' -e "/${key_pattern}/p")
  # Clear the terminal screen of the cruft that either gpg or its
  # agent puts out during the prompting process. Haven't figured
  # out which one it is, gave up for now.
}

function gpg_import_keys () {
  pushd "${GR_HOME}/engineering"        >/dev/null 2>&1
  if [[ "$(pwb)" != "master" ]] ; then
    echo "Engineering is not on master branch" 1>&2
  else
    git pull
    find ${GR_HOME}/engineering/gpg/public/ -type f -name '*.pub' -exec gpg --import {} ';'
  fi
  popd >/dev/null 2>&1
}

function gpgrep() {
  find . -type f -name '*.gpg' -exec sh -c "gpg -q -d --no-tty \"{}\" | grep -InH --color=auto --label=\"{}\" $*" \;
}
