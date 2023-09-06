# Use gpg-agent as my ssh-agent
export SSH_AUTH_SOCK="/run/user/$(id -u)/gnupg/S.gpg-agent.ssh"

# path_append is idempotent; gpg is in homebrew/bin
path_append /opt/homebrew/bin

function gpgenv  {
  gpg_file_name=${1:?gpg_file_name}

  if [ ! -f "${gpg_file_name}" ] ; then
    gpg_file_name=~/gpgs/"${gpg_file_name}".gpg
  fi

  if [ ! -r "${gpg_file_name}" ] ; then
    echo "Can't find ${gpg_file_name} or not readable" && return 1
  fi

  $(gpg -o - --use-agent --quiet ${gpg_file_name} | sed 's/#.*$//')
}

function gpg_agent_working {
  # *doesn't* work in the gnome startup world -- but tries to prompt
  # in a way that's super-ugly. So for now, turn it off entirely.
  return 1
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

  export $(gpg --use-agent -q --no-tty -o - $files 2>/dev/null | sed -n -e 's/#.*$//' -e "/${key_pattern}/p")
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
