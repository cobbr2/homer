#!/usr/bin/env bash

LINKTOHERE=./src/cc/cc/user/rick
for i in .?* ; do
    [ $i == '..' ] && continue
    [ $i == .ssh ] && continue
    if [ ! -L ~/$i -a -e "$LINKTOHERE/$i" ] ; then
        echo "Linking $i"
        mv ~/$i ~/$i.bak
        ln -s $LINKTOHERE/$i ~/$i
    fi
done
