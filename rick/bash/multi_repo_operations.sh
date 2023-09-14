#!/bin/bash
#

# Functions to be used in conjunction with `for_all_services` or `all_but`
#
# Hmm. There's a miscue on whether the functions can assume they're in the right
# repo or not. They should be able to assume that, and all arguments be associated
# with branches or whatever. If they need to know what repo they're in, they can
# call $(repo)
#
# At present, they all assume that their last argument is also the repo name, but
# that the global shell variable is set to the current repo when called.
update_bundler() {
  gem uninstall bundler
  gem install bundler
}

update_service_and_messaging () {
  master="bug/157060743/claims-events-reuse-their-event-uuids"

  set -x

  git pull
  if [ $? -ne 0 ]; then
    echo "$(repo): FAIL: git pull" 1>&2
    return
  fi

  git checkout "$master"
  if [ $? -ne 0 ]; then
    echo "$(repo): FAIL: No #${master} branch" 1>&2
    return
  fi

  bundle update --source grnds-service grnds-service-messaging
  if [ $? -ne 0 ]; then
    echo "$(repo): FAIL: Bundling" 1>&2
    return
  fi

  git commit -a -m 'Pull latest service & messaging gems'
  if [ $? -ne 0 ]; then
    echo "$(repo): FAIL: git commit" 1>&2
    return
  fi

  git push
  if [ $? -ne 0 ]; then
    echo "$(repo): FAIL: git push" 1>&2
    return
  fi

  echo "$(repo): Updated" 1>&2
}

update_service_and_messaging_from_branch () {
  master="bug/157060743/claims-events-reuse-their-event-uuids"
  branch="${1}"
  if [ -z "$branch" ] ; then
    echo "update_rack_based: Arg 1 must be branch" 1>&2
    return
  fi
  local repo=$(repo)
  if [ -z "$repo" ] ; then
    echo "update_rack_based: No repo provided as arg 2, and not in one now" 1>&2
    return
  fi

  set -x

  git checkout "$branch"
  if [ $? -ne 0 ]; then
    git checkout "$master"
    if [ $? -ne 0 ]; then return ; fi
    git pull
    if [ $? -ne 0 ]; then return ; fi
    git checkout -b "$branch"
    if [ $? -ne 0 ]; then return ; fi
  fi

  sed -i '/httparty/d' Gemfile.lock

  bundle update --source grnds-service grnds-service-messaging
  if [ $? -ne 0 ]; then return ; fi

  rake db:migrate
}

# Merge current master into branch ${1}
merge_master() {
  branch="${1}"
  if [ -z "$branch" ] ; then
    echo "merge_master: Arg 1 must be branch" 1>&2
    return
  fi
  git remote update --prune
  git checkout master
  git pull
  git checkout "$branch"
  git merge master
}

# Add all changes, commit and push the ${1} branch of the repo with the ${2} message
check_in() {
  branch="${1}"
  if [ -z "$branch" ] ; then
    echo "check_in: Arg 1 must be (new) branch" 1>&2
    return
  fi
  message="${2}"
  if [ -z "$message" ] ; then
    echo "check_in: Arg 2 must be commit message" 1>&2
    return
  fi

  if ! verify_on_branch ; then
    return
  fi

  git commit -a -n -m "${message}"
  if [ $? -ne 0 ]; then return ; fi

  push_branch "${branch}"
}

# Just pushes the branch; creates and sets up the upstream if it doesn't exist.
push_branch() {
  branch="${1}"
  if [ -z "$branch" ] ; then
    echo "push_branch: Arg 1 must be (new) branch" 1>&2
    return
  fi

  if ! verify_on_branch "${1}" ; then
    return
  fi

  if ! branch_committed ; then
    return
  fi

  if git rev-parse @{u} >/dev/null 2>&1 ; then
    git push
  else
    git push --set-upstream origin $branch
  fi
}

#
# Utility functions for use by the command functions above.
#
repo() {
  basename $(git_root)
}

verify_on_branch() {
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  if [ "${current_branch}" != "${1}" ] ; then
    echo "FAIL: Branch ${1} not checked out" 1>&2
    return 1
  fi
  return 0
}

branch_committed() {
  if [ -n "$(git status --porcelain)" ] ; then
    echo 'FAIL: Branch has uncommitted work' 1>&2
    return 1
  fi
  return 0
}

branch_clean() {
  if branch_committed ; then
    if [ -n "$(git log --oneline '@{u}..HEAD')" ] ; then
      echo 'FAIL: Branch has unpushed commits' 1>&2
      return 2
    fi
  else
    return $?
  fi
}

#
# Iterators and iterator support
#

# Yes, this is this hard in Bash. Verifies that "$2" is in the array sent in as
# ${1}.
array_contains () {
    local array="$1[@]"
    local seeking=$2
    local in=1
    for element in "${!array}"; do
        if [[ $element == $seeking ]]; then
            in=0
            break
        fi
    done
    return $in
}

in_repo () {
  local repo="${1}"
  if [ -z "$repo" ] ; then
    echo "in_repo: Arg 1 must be repo" 1>&2
    return
  fi
  shift
  command="${@}"
  pushd "${GR_HOME}/$repo" >/dev/null
    echo -e "\n-----\n${repo}\n-----"
    $command
    status=$?
    set +vx
  popd >/dev/null
  return $status
}

# Find all the repos that use a specific gem
ruby_users() {
  grep -l "${1}" ${GR_HOME}/*/Gemfile | sed "s;${GR_HOME}/\([^/]*\)/Gemfile;\1;"
}

SERVICE_REPOS=$(ruby_users grnds-service)
MESSAGING_REPOS=$(ruby_users grnds-service-messaging)

# Don't remember what tool needed this commafied.
service_repos() {
  echo -n "$SERVICE_REPOS" | tr ' \012' ',,'
}

set_repo_list() {
  if [ -n "${1}" ] ; then
    MRO_REPO_LIST="${@}"
  else
    unset MRO_REPO_LIST
  fi
}

repo_list() {
  echo "${MRO_REPO_LIST:-${SERVICE_REPOS}}"
}

# Deprecated: use for_all_repos and set the repo_list appropriately
for_all_services() {
  for service in $SERVICE_REPOS; do
    in_repo "${service}" "$@"
  done
}

# Usage: `for_all-repos <command> <options> <arguments>`
for_all_repos() {
  for repo in $(repo_list); do
    in_repo "${repo}" "$@"
  done
}

# Usage: `all_but <repo> <repo> <repo> <command> <options> <arguments>`
# Yes, this means your command must not match a repo name.
all_but() {
  repos=($(repo_list))

  local skippers=()
  while array_contains repos "${1}" ; do
    skippers+=("${1}")
    shift
  done
  echo "Ignoring ${skippers[*]}"

  for service in $(repo_list); do
    if array_contains skippers "$service" ; then
      echo -e "-----\nSkipped $service"
      continue
    fi

    in_repo "${service}" "$@"
  done
set +xv
}
