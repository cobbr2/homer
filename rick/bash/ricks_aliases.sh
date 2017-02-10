#
export EDITOR=vim
export EC2_HOME=/home/rick/ec2-api-tools
#export PATH=${PATH}:${EC2_HOME}/bin
#export EC2_PRIVATE_KEY=~/.ec2/pk.pem
#export EC2_CERT=~/.ec2/cert.pem
#export EC2_PRIVATE_KEY ~/.ec2/pk-U2CJWUZP3E4S2SAJBJ5P5BONVLBFFV3H.pem
#export EC2_CERT ~/.ec2/cert-U2CJWUZP3E4S2SAJBJ5P5BONVLBFFV3H.pem
#export JAVA_HOME=/usr
#export JAVA_OPTS "-Dsolr.solr.home=/home/rick/fun/Funambol/tools/tomcat/solr"



#bindkey ^Z run-fg-editor

alias tidy='find * .* -prune \( -name "*~" -o -name ".*~" -o -name "%*" -o -name "*%" -o -name ".*%" -o -name "#*#"  -o -name "core" \) -exec rm {} \; -print'
alias ls='ls --color'
alias lll='ls -ltra|tail'
alias ll='ls -ltr'
alias syslogs='tail -f /var/log/syslog'

alias ta='vi -t'
alias e='vi '

alias twinkle='cd ~/twinkleshine'
alias shine='cd ~/twinkleshine'

# Clean up when Zeus dies
function zzz {
  stty sane
  rm .zeus.sock
}

# Get to the top level of the product I'm working on.
cdr () {
  newdir=$(expr "$PWD" : "\($GR_HOME/[^/]*\)")
  pushd $newdir
}

devdirs () {
  ls -d --format=single-column --color=never ~/*/.git | sed 's/\/.git//'
}

grepall () {
  for dir in $(devdirs) ; do
    pushd $dir >/dev/null
    GIT_PAGER=cat gg $@
    popd >/dev/null
  done
}

rtags () {
  common_repos="${HOME}/frick ${HOME}/jarvis ${HOME}/stone"
  uncommon_repos="${HOME}/engineering ${HOME}/honesty ${HOME}/cargo"

  # TODO: Get it to search the right gem_home too
  find $common_repos -type f  | ctags -f ~/TAGS -L - 2>&1 | grep -v 'ignoring null tag'
  find $uncommon_repos -type f| ctags -f ~/TAGS.uncommon -L - 2>&1 | grep -v 'ignoring null tag'
}

h () {
    history ${1:-20}
}

work () {
  dir=${1}
  case $dir in
  ${HOME}*)
    ;;
  twink* | *shine)
    dir=~/twinkleshine
    ;;
  *)
    dir=~/${dir}
    ;;
  esac
  pushd $dir
}

crashed () {
  find ~ -name '*.sw[po]' | xargs rm
  rm ~/*/tmp/pids/*
  rm ~/jarvis/.zeus.sock
  rm ~/.mozilla/firefox/*/.parentlock
}

clip () {
  xclip -i -selection clipboard
}

fn_exists () {
  declare -f -F $1 > /dev/null
  return $?
}
