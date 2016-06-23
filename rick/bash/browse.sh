
function browse() {
  unix=$(uname)
  case $unix in
  Darwin*) open $@ ;;
  Linux*) sensible-browser $@ ;;
  *) echo "No browsability on ${unix}" ;;
  esac
}
