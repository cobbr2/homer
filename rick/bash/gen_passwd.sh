function genpass {
  # alias genpass='< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c8; echo'
   tr -dc '_A-Z-a-z-0-9' < /dev/urandom | head -c "${1:-8}"
   echo
}
