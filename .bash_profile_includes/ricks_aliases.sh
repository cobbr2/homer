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

alias gg="git grep --untracked" # Isn't there a way to default this in .gitconfig?
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

alias ta='vi -t'
alias e='vi '

function rtags {
  common_repos="${HOME}/frick ${HOME}/jarvis"
  uncommon_repos="${HOME}/engineering"

  # TODO: Get it to search the right gem_home too
  find $common_repos -type f  | ctags -f ~/TAGS -L - 2>&1 | grep -v 'ignoring null tag'
  find $uncommon_repos -type f| ctags -f ~/TAGS.uncommon -L - 2>&1 | grep -v 'ignoring null tag'
}

function h {
    history ${1:-20}
}

function work {
  pushd ~/${1}
}
