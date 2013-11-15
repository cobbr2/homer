#!/usr/bin/env bash

# For more comprehensive solution, see
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
for i in .?* ; do
    [ $i == '..' ] && continue
    [ $i == .ssh ] && continue
    if [ ! -L ~/$i -a -e "$DIR/$i" ] ; then
        echo "Linking $i"
        mv ~/$i ~/$i.bak
        ln -s $DIR/$i ~/$i
    fi
done
