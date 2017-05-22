
function creds() {
  local list_only=false
  local trace=false
  local usage="Usage: creds [ -l ] [ -x ] str... "
  local editor="${EDITOR:-vim}"

  while [ -n "$1" ] ; do
    case $1 in
    -l) editor=echo ;;
    -x) trace=true ;;
    -*) echo "$usage" 1>&2; return -1 ;;
    *) break ;;
    esac
    shift
  done

  local combinator=""
  local patterns=""
  while [ -n "$1" ] ; do
    patterns="-iname *${1}*${combinator}${patterns}"
    combinator=" -a "
    shift
  done

  if [ -z "${patterns}" ] ; then
    echo "No pattern strings given" 1>&2
    echo "$usage" 1>&2
    return -2
  fi

  if $trace ; then set -xv ; fi
  set -f
  $editor $(find ${GR_HOME}/engineering/credentials $patterns -print)
  set +f
  if $trace; then set +xv ; fi
}
