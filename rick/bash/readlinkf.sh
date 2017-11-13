# Just storing this here until I need it again.
#
# A bit of fun since MacOS doesn't have readlink -f
function readlinkf() {
  if readlink -f / >/dev/null 2>&1 ; then
    readlink -f "${1}"
  else
    # From https://stackoverflow.com/questions/1055671/how-can-i-get-the-behavior-of-gnus-readlink-f-on-a-mac
    # with changes to make it a shell function and handle loops.

    where_were_we="$(pwd)"

    local target_file=$1

    cd $(dirname $target_file)
    target_file=`basename $target_file`
    max_depth=20

    # Iterate down a (possible) chain of symlinks
    while [ -L "$target_file" ]
    do
      target_file=$(readlink $target_file)
      cd `dirname $target_file`
      target_file=$(basename $target_file)

      if [[ 0 == $((max_depth-=1)) ]] ; then
        echo "Max symlink depth reached" 1>&2
        cd "${where_were_we}"
        return 6
      fi
    done

    # Compute the canonicalized name by finding the physical path
    # for the directory we're in and appending the target file.
    echo "$(pwd -P)/${target_file}"
    cd "${where_were_we}"
    return 0
  fi
}
