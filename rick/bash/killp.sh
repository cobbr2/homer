#!/bin/bash
#
function killp() {
  local command="kill"
  while true ; do
    case $1 in
    -n) command="echo"
        shift
        ;;
    -*) command="$command $1"
        shift
        ;;
    *)  break;;
    esac
  done
  ps -ef | awk "/$1/"' && !/awk/ { print $2 }' | xargs $command
}
