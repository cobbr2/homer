
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

# Not implementing the actual color stuff today; don't know how that worked
# on Linux
color() {
  local color=${1}
  shift
  echo "${@}"
}

# I'm going to assume I've cloned and that the upstream I care about is origin;
# that makes this pretty easy and gets rid of wacky hacks.  If we run into issues
# where the main branch name has changed since origin was first cloned,
#    git remote set-head origin -a
# should fix, according to https://stackoverflow.com/a/62397081
main_branch()
{
  fullpath=$(git rev-parse --abbrev-ref origin/HEAD)
  if [ $? != 0 ] ; then
    echo "New repo? Setting head alias from origin" 1>&2
    git remote set-head origin -a
    if [ $? != 0 ] ; then
      echo "Set-head origin failed, main_branch giving up" 1>&2
      return 2
    fi
    fullpath=$(git rev-parse --abbrev-ref origin/HEAD)
    if [ $? != 0 ] ; then
      echo "Hmm, main_branch giving up" 1>&2
      return 1
    fi
  fi

  basename "${fullpath}"
}

branch_cleanup () {
  local branch_excludes
  branch_excludes=cat
  if [ -n "$1" ] ; then
    branch_excludes="grep -v ${1}"
  fi
  pushd $(git_root)
  git remote update --prune
  local master=$(main_branch)
  if [ $? != 0 -o -z "${master}" ] ; then
    return 1
  fi
  if git checkout "$master" ; then
    git merge "origin/$master"
    # At GR, don't push the deletion to remote, since
    # we delete branches on merge.
    git branch --merged | grep -v '^\*' | ${branch_excludes} | xargs -L 1 -r git branch -d
  else
    echo $(color red Get your branch clean first!)
  fi
  popd
}

# Extra subshell lets us use -e rather than &&\ chaining.
# Use this b4 branch_cleanup; branch_cleanup will kill the state necessary for this to work.
squashmerge_cleanup() {(
  local branch_excludes=cat
  if [ -n "$1" ] ; then
    branch_excludes="grep -v ${1}"
  fi
  pushd $(git_root)
  git remote update

  set -e
  git checkout $(main_branch)
  git remote prune --dry-run origin |\
    sed -n 's;^.*origin/;;gp' |\
    ${branch_excludes} |\
    xargs -L1 -r git branch -D
)}

pwb () {
  git status | sed -n -e '/On branch/s;^.* ;;p'
}

# Needs to be a bin to be used with `git root`. Someday
git_root() {
  git rev-parse --show-toplevel
}

prme() {
  local master=$(main_branch)
  if [ $? != 0 -o -z "${master}" ] ; then
    return 1
  fi

  ${GR_HOME}/engineering/bin/prme -t "$(main_branch)" ${@}
}
