
alias gg="git grep --untracked" # Isn't there a way to default this in .gitconfig? (apparently not)
alias gs="git status "
alias gc="git checkout "
alias gb="git branch "
alias gd="git diff --no-index"
alias gr="git checkout -- " # revert a single file
alias ga="git add "
alias gt="git commit "
alias gl="git log "
alias glf="git log --stat --follow "
alias glfd="git log --stat --follow --patch-with-raw "
alias gls="git log --no-merges --pretty=medium --stat"
alias gp="git pull"

branch_cleanup () {
  local branch_excludes
  branch_excludes=cat
  if [ -n "$1" ] ; then
    branch_excludes="grep -v ${1}"
  fi
  git remote update --prune
  git checkout master
  git merge origin/master
  # At GR, don't push the deletion to remote, since
  # we delete branches on merge.
  git branch --merged | grep -v '^\*' | ${branch_excludes} | xargs -L 1 --no-run-if-empty git branch -d
}

pwb () {
  git status | sed -n -e '/On branch/s;^.* ;;p'
}
