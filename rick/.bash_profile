#
# vi: ft=bash
#
# /usr/local/bin first to pick up exuberant ctags on Mac.
# May regret that decision later.
#
# NEED TO INSTALL CTAGS again
PATH="/usr/local/bin:$PATH:/opt/local/bin:/opt/local/sbin"

if [ -d "$HOME/.rvm" ] ; then
    [[ -s "$HOME/.rvm/scripts/rvm" ]] && . "$HOME/.rvm/scripts/rvm"  # This loads RVM into a shell session.
fi

source "/etc/profile.d/rvm.sh"

umask 002

# --- Aliases ---
alias gs="git status "
alias gc="git checkout "
alias gb="git branch "
alias gd="git diff "
alias gr="git checkout -- " # revert a single file
alias ga="git add "
alias gt="git commit "
alias gl="git log "
alias glf="git log --stat --follow "
alias glfd="git log --stat --follow --patch-with-raw "
alias gls="git log --no-merges --pretty=medium --stat"
alias gp="git pull"

# Removed these, instead symlinked in /opt/local/bin . That
# makes innobackupex happier.
#if [ $(uname -s) == Darwin ] ; then
#    alias mysql='mysql5'
#    alias mysqladmin='mysqladmin5'
#    alias mysqldump='mysqldump5'
#    alias mysqlimport='mysqlimport5'
#fi

alias ta='vi -t'
alias e='vi '
alias ctags='ctags -f TAGS -R'


# --- Non-PATH-affecting Environment Variables ---

# Get coloring for ls & others.
export CLICOLOR=ANSI

export CCROOT=${HOME}/src/cc/cc
export CCALT=${HOME}/spinner/src/cc/cc

# From the bash book: non-printing escape sequences have to be enclosed in \[\033[ and \].
#  Setting things on the title bar is non-printing.
#  Single quotes gets the tpwd executed on every command.
PS1='\[\033[$(tpwd)\]\h:\W \u\$ '

export EDITOR=`which vim`

# --- Functions ---

function work {
    if [ -d $CCROOT/$1 ] ; then
        pushd $CCROOT/$1
    else
        pushd $1
    fi
    ttitle $1
}

function spork {
    if [ -d $CCALT/$1 ] ; then
        pushd $CCALT/$1
    else
        pushd $1
    fi
    ttitle $1
}

function york {
    pushd ~/spinner/src/Arduino${1:+/$1}
}

function devdb {
    rpl _live _dev $CCROOT/*/config/database.yml
    rpl _live _dev $CCROOT/*/config/database.yml.global
}
function proddb {
    rpl _dev _live $CCROOT/*/config/database.yml
    rpl _dev _live $CCROOT/*/config/database.yml.global
}

function get_ccdb {
    mysqldump -C -v -e --single-transaction -h corsair -u user cloudcrowd_live | mysql -u root cc_live
}

function ssh_get_ccdb {
    ssh corsair 'mysqldump -C -v -e --single-transaction -u user cloudcrowd_live | gzip -c' | gunzip -c | mysql -u root cc_live
}

function get_ezdb {
    mysqldump -C -v -e --single-transaction -h corsair -u user ez_live | mysql -u root ez_live
}

function get_rzdb {
    mysqldump -C -v -e --single-transaction -h corsair -u user rz_live | mysql -u root rz_live
}

function get_woprdb {
    mysqldump -C -v -e --single-transaction -h corsair -u user wopr_live | mysql -u root wopr_live
}

function amqp {
    echo 'NAME	RDY	UNACK	CONS	MEMORY'
    #sudo rabbitmqctl list_queues -p thevhost {name,messages_ready,messages_unacknowledged,consumers,memory}
    sudo rake mq:queues
    #sudo rabbitmqctl list_queues {name,messages_ready,messages_unacknowledged,consumers,memory}
}

function reset_amqp {
    sudo rabbitmqctl stop_app
    sudo rabbitmqctl reset
    sudo rabbitmqctl start_app
    sudo rabbitmqctl add_vhost thevhost
    sudo rabbitmqctl add_user theuser thepassword
    sudo rabbitmqctl set_permissions -p thevhost theuser ".*" ".*" ".*"
    amqp
    date +'%Y/%m/%d %H:%M AMQP reset done'
}

function ccscreen {
    tscreen -c ~/.ccscreen
}

function h {
    history ${1:-20}
}

function sockkill {
    lsof -i @${2:-0.0.0.0}:${1:?Port required} | awk 'NR > 1 { print "kill " $2 }'  | sh
}

function ttitle {
    if [ -z "$HOST" ] ; then
        HOST=$(expr $(uname -n) : '\([^.]*\)')
        if [ $HOST != "0022-MBP-Rick" ] ; then
            export NON_KWYJI_HOST="$HOST"
        fi
    fi
    case "$TERM" in
        xterm* )
            echo -n -e "\033]0;${NON_KWYJI_HOST:+$NON_KWYJI_HOST:}${1}\007"
            ;;
    esac
}

function ziplog {
    app=${1:-$(basename $PWD)}
    olog=${app}.log
    nlog=~/Downloads/_${app}_$(date +'%a_%H%M').log
    if [ -f $olog ] ; then mv $olog $nlog; gzip $nlog; > $olog; fi
}

function mackup {
    ziplog
    rackup $@
}

function tpwd {
    ttitle ${PWD##${CCROOT}/}
}

function findrb {
    find . -type f -name '*.rb' -print0
}

function findex {
    find . -type f -name "*.${1}" -print0
}

# Yeah. "$@". Not bashful about bash magic. (Remember that
# expands to separate strings per argument)
function greprb {
    find . -type f -name '*.rb' -print0 | xargs -0 grep "$@"
}

grepex () {
    ex="$1"
    shift
    find . -type f -name "*.${ex}" -print0 | xargs -0 grep "$@"
}

if [ $(uname -s) == Darwin ] ; then
    export RACKDIR=/system/Library/Frameworks/Ruby.framework/Versions/1.8/usr/lib/ruby/gems/1.8/gems/rack-1.0.1/lib/rack
fi

function rskwai {
    ssh rskwai "$@"
}

# "Ticket Checkout"; go to a ticket branch if it exists, else create it.
tc ()
{
    b=$1;
    if git checkout $b; then
        : true;
    else
        git checkout -b $b;
        git push origin $b;
        git branch --set-upstream $b origin/$b;
    fi
}

# "Ticket Delete"; if we can succesfully delete the branch, also
# push the deletion to the origin
tdelete ()
{
    # Necessary to avoid the 'destination refspec neither matches...' error
    git remote prune origin
    b=$1
    if git branch --merged | grep '^  '"$b"'$' ; then
        git branch -d "$b"
        if git branch -r | grep "origin/$b" ; then
            git push origin ":$b"
        fi
    else
        echo "ReC: Not merged into current HEAD (or is current branch)" 1>&2
    fi
}

# "branch cleanup":
#       Remove all branches that are merged into the current branch
#       Restricts pushes to those where remote exists and name matches
#       a pattern, which defaults to the user name
branch_cleanup()
{
    git remote update --prune origin
    branches=`git branch --merged | egrep -v '\*|master'`
    killable_remote_pattern=${1:-"$USER/"}
    echo "Pattern: '${killable_remote_pattern}'"
    remotes="/tmp/_$$_xx"
    git branch -r >${remotes}

    for branch in $branches ; do
        git branch -d "$branch"

        if [[ "${branch}" =~ ${killable_remote_pattern} ]] ; then

            if grep "^origin/${branch}"'$' ${remotes} ; then
                git push origin ":${branch}"
            fi

        else
            echo "'${branch}' no matchie '${killable_remote_pattern}'; not pushing deletion"
        fi
    done
    rm "${remotes}"
}


# Keep my tags up to date
rtags ()
{
    # Uses exuberant tags, of course, since we're exuberantly Ruby folks
    # In conjunction with setting the search path to be ... TAGS,TAGS.uncommon,
    # this ensures that the stuff I want to find (Ez::Order) comes up sooner
    # in my stack than stuff embedded in our local gems (ActiveRecord::Order).
    # Haven't added the system gem library in, but will probably get around
    # to that sometime. Also, would be cool to trigger rebuilds on gc, if they
    # were faster.
    find $CCROOT -type f -print | egrep -v '(common/gems|common/javascripts|.xml$)' | /usr/local/bin/ctags -f ~/TAGS -L - 2>&1 | grep -v 'ignoring null tag'
    find $CCROOT -type f -print | egrep  '(common/gems|common/javascripts)' | /usr/local/bin/ctags -f ~/TAGS.uncommon -L - 2>&1 | grep -v 'ignoring null tag'
}

# Keep my tags up to date
alttags ()
{
    # Uses exuberant tags, of course, since we're exuberantly Ruby folks
    # In conjunction with setting the search path to be ... TAGS,TAGS.uncommon,
    # this ensures that the stuff I want to find (Ez::Order) comes up sooner
    # in my stack than stuff embedded in our local gems (ActiveRecord::Order).
    # Haven't added the system gem library in, but will probably get around
    # to that sometime. Also, would be cool to trigger rebuilds on gc, if they
    # were faster.
    CCALT=${1:-~/spinner/src/cc/cc}
    find $CCALT -type f -print | egrep -v '(common/gems|common/javascripts|.xml$)' | /usr/local/bin/ctags -f $CCALT/TAGS -L - 2>&1 | grep -v 'ignoring null tag'
    find $CCALT -type f -print | egrep  '(common/gems|common/javascripts)' | /usr/local/bin/ctags -f $CCALT/TAGS.uncommon -L - 2>&1 | grep -v 'ignoring null tag'
}

# Get working branch into a variable. From
# http://stackoverflow.com/questions/1593051/how-to-programmatically-determine-the-current-checked-out-git-branch
pwb ()
{
    PWB=$(git symbolic-ref -q HEAD)
    PWB=${PWB##refs/heads/}
    export PWB=${PWB:-HEAD}
}

function cr ()
{
    pwb
    git log -p $(git merge-base ${1:-master} ${PWB})..${PWB}
}

# TODO: Figure out your argument parsing.
function crdiff ()
{
    pwb
    git diff $(git merge-base ${1:-master} ${PWB})..${PWB} .
}

# Show ttys for open files in this directory (or tmps)
function vit ()
{
    vi -re 2>&1 | awk '/^ *process ID:/ { print "ps -ef | grep " $3 " | grep -v grep" }' | sh | awk '{print $6}'
}

function backup_db ()
{
    #!/bin/bash
    if [ ! -d ~/dumps ] ; then
        mkdir ~/dumps
    fi
    pushd ~/dumps
    rm -rf dump/
    rm -f cc.sql.gz
    rm -f ez.sql.gz
    echo "dumping ez"
    mysqldump5 -uroot ez | gzip > ez.sql.gz
    echo "dumping cc"
    mysqldump5 -uroot cc | gzip > cc.sql.gz
    echo "dumping servio"
    mongodump -d servio
    popd
}

function restore_db ()
{
    #!/bin/bash
    pushd ~/dumps
    echo "restoring cc"
    zcat cc.sql.gz | mysql5 cc -uroot
    echo "restoring ez"
    zcat ez.sql.gz | mysql5 ez -uroot
    echo "restoring servio"
    mongorestore -d servio dump/servio
    popd
}

function ppxml ()
{
    xmllint --format --recover ${1:-'-'}  2>/dev/null
}

##
# Your previous /Users/rick/.profile file was backed up as /Users/rick/.profile.macports-saved_2012-10-08_at_09:50:59
##

# MacPorts Installer addition on 2012-10-08_at_09:50:59: adding an appropriate PATH variable for use with MacPorts.
export PATH=/opt/local/bin:/opt/local/sbin:$PATH
# Finished adapting your PATH environment variable for use with MacPorts.
