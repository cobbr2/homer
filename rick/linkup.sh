#!/usr/bin/env bash
#
# RUN from the github `rick` directory!

#LINKTOHERE=./src/cc/cc/user/rick
LINKTOHERE=${PWD}
for i in .?* ; do
    [ $i == '..' ] && continue
    [ $i == .ssh ] && continue
    if [ ! -L ~/$i -a -e "$LINKTOHERE/$i" ] ; then
        echo "Linking $i"
        mv ~/$i ~/$i.bak
        ln -s $LINKTOHERE/$i ~/$i
    fi
done
