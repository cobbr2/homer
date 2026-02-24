
alias gg="git grep --untracked" # Isn't there a way to default this in .gitconfig? (apparently not)
alias gs="git status "
alias gc="git switch "
alias gb="git branch "
alias gd="git diff --no-index"
alias ga="git add "
alias gt="git commit "
alias gl="git log "
alias glf="git log --stat --follow "
alias glfd="git log --stat --follow --patch-with-raw "
alias gls="git log --no-merges --pretty=medium --stat"
alias gp="git pull"
alias branch-cleanup=branch_cleanup

# Wrapper to auto-refresh work completions cache on worktree changes.
# Aliases like gc="git switch" expand first, then dispatch through here;
# `command git` ensures we call the real binary.
git() {
  command git "$@"
  local rc=$?
  case "$1" in
  worktree)
    case "${2:-}" in
    add|remove|prune|move)
      ( work-refresh >/dev/null 2>&1 & )
      ;;
    esac
    ;;
  esac
  return $rc
}

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

# --- Worktree-aware helpers ---

_worktree_branches() {
  git worktree list --porcelain | sed -n 's;^branch refs/heads/;;p'
}

# Remove worktrees whose upstream tracking branch is gone from remote.
# Run after `git remote update --prune` so upstream status is current.
_cleanup_stale_worktrees() {
  local wt_path="" wt_branch="" line
  while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.*) ]]; then
      wt_path="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^branch\ refs/heads/(.*) ]]; then
      wt_branch="${BASH_REMATCH[1]}"
      local track
      track=$(git for-each-ref --format='%(upstream:track)' "refs/heads/$wt_branch")
      if [ "$track" = "[gone]" ]; then
        echo "Removing stale worktree: $wt_path (branch: $wt_branch)"
        git worktree remove "$wt_path" 2>/dev/null || \
          echo "  Could not auto-remove; try: git worktree remove --force \"$wt_path\""
      fi
    elif [ -z "$line" ]; then
      wt_path=""; wt_branch=""
    fi
  done < <(git worktree list --porcelain)
}

# Pipe branch names through this to exclude branches checked out in worktrees.
# Handles leading whitespace/asterisks from `git branch` output.
_exclude_worktree_branches() {
  local wt_branches
  wt_branches=$(_worktree_branches)
  if [ -z "$wt_branches" ]; then
    cat
    return
  fi
  while IFS= read -r line; do
    local trimmed
    trimmed=$(echo "$line" | sed 's/^[ *+]*//')
    if [ -n "$trimmed" ] && echo "$wt_branches" | grep -qFx "$trimmed"; then
      echo "Skipping branch in worktree: $trimmed" >&2
    else
      echo "$line"
    fi
  done
}

# --- Branch cleanup functions ---

branch_cleanup () {
  local branch_excludes=cat
  if [ -n "$1" ] ; then
    branch_excludes="grep -v ${1}"
  fi
  pushd $(git_root)
  git remote update --prune
  local master=$(main_branch)
  if [ $? != 0 -o -z "${master}" ] ; then
    popd; return 1
  fi
  _cleanup_stale_worktrees
  if git switch "$master" 2>/dev/null; then
    git merge "origin/$master"
    # At GR, don't push the deletion to remote, since
    # we delete branches on merge.
    git branch --merged | grep -v '^\*' | _exclude_worktree_branches | ${branch_excludes} | xargs -L 1 -r git branch -d
  else
    echo "Note: $master checked out in another worktree; cleaning merged branches from here."
    git branch --merged "origin/$master" | grep -v '^\*' | _exclude_worktree_branches | ${branch_excludes} | xargs -L 1 -r git branch -d
  fi
  popd
}

# Use this b4 branch_cleanup; branch_cleanup will kill the state necessary for this to work.
squashmerge_cleanup() {(
  local branch_excludes=cat
  if [ -n "$1" ] ; then
    branch_excludes="grep -v ${1}"
  fi
  pushd $(git_root)
  git remote update
  local master=$(main_branch)
  if [ $? != 0 -o -z "${master}" ] ; then
    popd; return 1
  fi
  _cleanup_stale_worktrees
  if ! git switch "$master" 2>/dev/null; then
    echo "Note: $master checked out in another worktree; detaching HEAD."
    git checkout --detach
  fi
  git remote prune --dry-run origin |\
    sed -n 's;^.*origin/;;gp' |\
    _exclude_worktree_branches |\
    ${branch_excludes} |\
    xargs -L1 -r git branch -D
  popd
)}

# prune removes any branches that have deleted upstreams. Doesn't
# care about merge status, so can be dangerous -- it'll get rid of
# any experimental branches we haven't pushed.
branch_prune() {
  _cleanup_stale_worktrees
  git for-each-ref --format '%(refname:short) %(upstream:track)' | \
    awk '$2 == "[gone]" {print $1}' | \
    _exclude_worktree_branches | \
    xargs -r git branch -D
}

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
