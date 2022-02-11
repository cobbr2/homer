unalias genpass genpass_simple 2>/dev/null

function genpass {
  pattern='_A-Z-a-z-\!-9'
  if [ "$1" == '-s' ] ; then
    pattern='_A-Z-a-z-0-9'
    shift
  fi
  # alias genpass='< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c8; echo'
  LC_ALL=C tr -dc "$pattern" < /dev/urandom | head -c "${1:-16}"
  echo
}
