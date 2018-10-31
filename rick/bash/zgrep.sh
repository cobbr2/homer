
# Wow, Linux's Zgrep sucks (no -R; can't handle shell expansions on the command line like zgrep 'foo' */*). So does this, but...
reczgrep () {
  no_recurse='-maxdepth 1'
  while [ $# -gt 0 ] ; do
    case $1 in
    -R)         no_recurse='' ;;
    esac
    shift
  done

  # Do the uncompressed ones first
  find "${@}" "${norecurse}" 


}
