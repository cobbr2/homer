
alias gg="git grep --untracked" # Isn't there a way to default this in .gitconfig? (apparently not)
alias gs="git status "
alias gc="git checkout "
alias gb="git branch "
alias gd="git diff --no-index"
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
  pushd $(git_root)
  git remote update --prune
  if git checkout master ; then
    git merge origin/master
    # At GR, don't push the deletion to remote, since
    # we delete branches on merge.
    git branch --merged | grep -v '^\*' | ${branch_excludes} | xargs -L 1 --no-run-if-empty git branch -d
  else
    echo $(color red Get your branch clean first!)
  fi
  popd
}

pwb () {
  git status | sed -n -e '/On branch/s;^.* ;;p'
}

# Needs to be a bin to be used with `git root`. Someday
git_root() {
  git rev-parse --show-toplevel
}
