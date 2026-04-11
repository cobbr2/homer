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

export DISABLE_SPRING=1


#bindkey ^Z run-fg-editor

alias tidy='find * .* -prune \( -name "*~" -o -name ".*~" -o -name "%*" -o -name "*%" -o -name ".*%" -o -name "#*#"  -o -name "core" \) -exec rm {} \; -print'

if [ $RICK_OS == "Darwin" ] ; then
  alias ls='ls -G'
else
  alias ls='ls --color'
fi
alias lll='ls -ltra|tail'
alias ll='ls -ltr'

alias ta='vi -t'
alias e='vi '

alias be='bundle exec'

alias more='less -R'

alias puhsd=pushd
alias pusdh=pushd

export I="${GR_HOME}"

# Get to the top level of the product I'm working on.
cdr () {
  pushd $(git_root)
}

devdirs () {
  ls -d --format=single-column --color=never ${GR_HOME}/*/.git ~/foss/*/.git | sed 's/\/.git//'
}

grepall () {
  for dir in $(devdirs) ; do
    pushd $dir >/dev/null
    GIT_PAGER="sed 's;^;${dir}/;'" gg "${@}"
    popd >/dev/null
  done
}

ltags() {
  cdr >/dev/null
  local also_exclude=''
  if [ -r .ctagsignore ] ; then
    also_exclude="--exclude=@.ctagsignore"
  fi
  ctags -f TAGS -R $also_exclude --exclude=node_modules --exclude=tmp .
  popd >/dev/null
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

find_repo() {
  local org_path="${GITHUB_ORG_PATH:-ConsultingMD:doctorondemand:GRH_IT}"
  repo="${1:?First argument to find_repo must be repo name}"
  OIFS="${IFS}"
  IFS=:
  for org in $org_path ; do
    IFS="${OIFS}"
    repo_url=git@github.com:"${org}/${repo}".git
    if git ls-remote "${repo_url}" >/dev/null 2>&1 ; then
      echo "${repo_url}"
      return 0
    fi
  done
  return 1
}

clone_ih_repo() {
  pushd ${GR_HOME}
  repo=$(find_repo "${1:?'Repo?'}")
  if [ -n "${repo}" ] ; then
    git clone "${repo}"
  fi
  popd
}

# Search for a service/component in pseudo-monorepos (kafka, potluck)
# Returns the first matching directory path, or empty if not found
# Usage: _find_in_monorepo <name> [prefer_source]
#   If prefer_source is "source", source directories are searched first
_find_in_monorepo() {
  local name="${1}"
  local prefer="${2:-container}"  # "source" or "container"
  local alt_name="${name//-/}"    # Remove hyphens: loading-dock -> loadingdock
  local alt_name2="${name//_/-}"  # Underscores to hyphens
  local found=""
  
  # Build search paths based on preference
  local kafka_paths=(
    "${IH_HOME}/kafka/platform/${name}"
    "${IH_HOME}/kafka/docker/${name}"
  )
  
  local potluck_container_paths=(
    "${IH_HOME}/potluck/platform/${name}"
    "${IH_HOME}/potluck/containers/${name}"
  )
  
  local potluck_source_paths=(
    "${IH_HOME}/potluck/scala/src/main/com/grandrounds/${name}"
    "${IH_HOME}/potluck/python/${name}"
    "${IH_HOME}/potluck/go/${name}"
    "${IH_HOME}/potluck/java/src/main/com/grandrounds/${name}"
  )
  
  # Also check alternate names (without hyphens)
  if [ "${alt_name}" != "${name}" ]; then
    potluck_source_paths+=(
      "${IH_HOME}/potluck/scala/src/main/com/grandrounds/${alt_name}"
      "${IH_HOME}/potluck/python/${alt_name}"
      "${IH_HOME}/potluck/go/${alt_name}"
    )
    potluck_container_paths+=(
      "${IH_HOME}/potluck/containers/${alt_name}"
    )
  fi
  
  # Order search based on preference
  local search_order=()
  if [ "${prefer}" = "source" ]; then
    search_order=("${potluck_source_paths[@]}" "${potluck_container_paths[@]}" "${kafka_paths[@]}")
  else
    search_order=("${kafka_paths[@]}" "${potluck_container_paths[@]}" "${potluck_source_paths[@]}")
  fi
  
  for path in "${search_order[@]}"; do
    if [ -d "${path}" ]; then
      echo "${path}"
      return 0
    fi
  done
  
  return 1
}

# List all matches in pseudo-monorepos (for debugging/info)
_find_all_in_monorepo() {
  local name="${1}"
  local alt_name="${name//-/}"
  local names=("${name}")
  [ "${alt_name}" != "${name}" ] && names+=("${alt_name}")
  
  local all_patterns=(
    "${IH_HOME}/kafka/platform"
    "${IH_HOME}/kafka/docker"
    "${IH_HOME}/potluck/platform"
    "${IH_HOME}/potluck/containers"
    "${IH_HOME}/potluck/scala/src/main/com/grandrounds"
    "${IH_HOME}/potluck/python"
    "${IH_HOME}/potluck/go"
    "${IH_HOME}/potluck/java/src/main/com/grandrounds"
  )
  
  for n in "${names[@]}"; do
    for base in "${all_patterns[@]}"; do
      local path="${base}/${n}"
      if [ -d "${path}" ]; then
        echo "${path}"
      fi
    done
  done
}

_work_prepare() {
  git rev-parse --git-dir >/dev/null 2>&1 || return 0

  local default_branch current_branch
  default_branch=$(main_branch 2>/dev/null) || return 0
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || return 0

  [ "$current_branch" = "$default_branch" ] || return 0

  local porcelain
  porcelain=$(git status --porcelain 2>/dev/null)

  # If anything other than tng.yaml has changes, leave the repo alone
  local other_changes
  other_changes=$(printf '%s\n' "$porcelain" | grep -v '^$' | grep -v 'tng\.yaml$')
  [ -z "$other_changes" ] || return 0

  # Discard tng.yaml if present (untracked vs. modified need different commands)
  if printf '%s\n' "$porcelain" | grep -q 'tng\.yaml$'; then
    if printf '%s\n' "$porcelain" | grep -q '^?? .*tng\.yaml$'; then
      git clean -f tng.yaml
    else
      git restore tng.yaml
    fi
  fi

  branch-cleanup
}

work() {
  local prefer_source="${2:-}"  # Optional second arg: "source" or "src" to prefer source dirs
  case "${1}" in
  Downloads | Documents | Desktop | .bash )
    dir=~/${1}
    ;;
  terraf[or][ro]m[-_]s*[-_]modules | tsm)
    dir="${IH_HOME}/terraform-service-modules"
    ;;
  * )
    dir="${IH_HOME}/${1}"
    if [ ! -d "$dir" ] ; then
      # Check worktree cache for worktrees not directly in ih_home
      local wt_path
      wt_path=$(grep "^${1}:" "${_WORKTREE_CACHE}" 2>/dev/null | head -1 | cut -d: -f2-)
      if [ -n "$wt_path" ] && [ -d "$wt_path" ]; then
        dir="$wt_path"
      else
        case "${1}" in
        */* ) echo "No such file or directory: ${dir}" ; return -1 ;;
        esac
        # Try to find in pseudo-monorepos (kafka, potluck)
        local monorepo_dir
        if [ "${prefer_source}" = "source" ] || [ "${prefer_source}" = "src" ]; then
          monorepo_dir=$(_find_in_monorepo "${1}" source)
        else
          monorepo_dir=$(_find_in_monorepo "${1}")
        fi
        if [ -n "${monorepo_dir}" ]; then
          dir="${monorepo_dir}"
          echo "(found in ${dir#${IH_HOME}/})"
        else
          # Not found locally, try cloning
          clone_ih_repo ${1}
          if [ -d "$dir" ]; then
            work-refresh
          fi
        fi
      fi
    fi
    ;;
  esac
  pushd "$dir"
  _work_prepare
}

# Variant of work that prefers source directories over containers
works() {
  work "${1}" source
}

# Show all monorepo matches for a name
workall() {
  local name="${1:?'Name?'}"
  local matches
  matches=$(_find_all_in_monorepo "${name}")
  if [ -z "${matches}" ]; then
    # Check if it's a direct repo
    if [ -d "${IH_HOME}/${name}" ]; then
      echo "${IH_HOME}/${name}"
    else
      echo "No matches found for '${name}'"
      return 1
    fi
  else
    echo "${matches}"
  fi
}

# Cache file for work command completions (regenerate with work-refresh)
_WORK_CACHE="${HOME}/.cache/work_completions"
# Worktree path mapping: basename -> absolute path (for worktrees outside ih_home top-level)
_WORKTREE_CACHE="${HOME}/.cache/work_worktrees"

# Regenerate the work completions cache
work-refresh() {
    local IH="${IH_HOME:-$HOME/ih_home}"
    local cache_dir="${HOME}/.cache"
    [ -d "$cache_dir" ] || mkdir -p "$cache_dir"
    
    # Build worktree path mapping (basename -> absolute path).
    # Reads gitdir files directly — no git commands, pure filesystem.
    > "${_WORKTREE_CACHE}"
    local gitdir_file wt_git_path wt_dir
    for gitdir_file in "${IH}"/*/.git/worktrees/*/gitdir; do
        [ -f "$gitdir_file" ] || continue
        read -r wt_git_path < "$gitdir_file"
        wt_dir=$(dirname "$wt_git_path")
        echo "$(basename "$wt_dir"):${wt_dir}" >> "${_WORKTREE_CACHE}"
    done
    
    {
        # Top-level ih_home directories
        if [ -d "${IH}" ]; then
            ls -1 "${IH}" 2>/dev/null
        fi
        
        # Kafka pseudo-monorepo
        for base in "${IH}/kafka/platform" "${IH}/kafka/docker"; do
            [ -d "$base" ] && ls -1 "$base" 2>/dev/null
        done
        
        # Potluck containers/platform
        for base in "${IH}/potluck/containers" "${IH}/potluck/platform"; do
            [ -d "$base" ] && ls -1 "$base" 2>/dev/null
        done
        
        # Potluck source directories
        for base in "${IH}/potluck/scala/src/main/com/grandrounds" \
                    "${IH}/potluck/python" \
                    "${IH}/potluck/go" \
                    "${IH}/potluck/java/src/main/com/grandrounds"; do
            [ -d "$base" ] && ls -1 "$base" 2>/dev/null
        done

        # Bobs if it exists
        for base in "${IH}/bobs/services" "${IH}/bobs/libs"; do
            [ -d "$base" ] && ls -1 "$base" 2>/dev/null
        done

        # Worktree basenames (catches worktrees outside ih_home top-level)
        if [ -s "${_WORKTREE_CACHE}" ]; then
            cut -d: -f1 "${_WORKTREE_CACHE}"
        fi
    } | grep -v '^_' | sort -u > "${_WORK_CACHE}"
    
    local wt_count=0
    [ -s "${_WORKTREE_CACHE}" ] && wt_count=$(wc -l < "${_WORKTREE_CACHE}")
    echo "Refreshed work completions cache: $(wc -l < "${_WORK_CACHE}") entries (${wt_count} worktrees)"
}

_work_complete() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    
    # If cache doesn't exist, generate it in background and use slow path once
    if [ ! -f "${_WORK_CACHE}" ]; then
        # Generate cache in background for next time
        ( work-refresh >/dev/null 2>&1 & )
        # Fall back to just ih_home top-level for now
        local IH="${IH_HOME:-$HOME/ih_home}"
        COMPREPLY=( $(compgen -W "$(ls -1 "${IH}" 2>/dev/null)" -- "$cur") )
        return
    fi
    
    # Detect worktree additions/removals (catches IDE-created worktrees; ~10ms)
    local IH="${IH_HOME:-$HOME/ih_home}"
    local wt_now=0 cached_wt=0
    wt_now=$(ls -d "${IH}"/*/.git/worktrees/*/gitdir 2>/dev/null | wc -l)
    [ -f "${_WORKTREE_CACHE}" ] && cached_wt=$(wc -l < "${_WORKTREE_CACHE}")
    [ "$wt_now" -ne "$cached_wt" ] 2>/dev/null && ( work-refresh >/dev/null 2>&1 & )

    # Fast path: use cached completions
    COMPREPLY=( $(grep "^${cur}" "${_WORK_CACHE}" 2>/dev/null) )
}
complete -o nospace -F _work_complete work
complete -o nospace -F _work_complete works

grr () {
  cd "${GR_HOME}"
}

foss () {
  export FOSS=~/foss
  if [ $# -eq 0 ] ; then
    pushd ${FOSS}
    return 0
  fi

  case "x-${1:-y}" in
  x-http*:* | x-git*:* )
    dir="${FOSS}/$(basename "${1}")"
    repo="${1}"
    ;;
  x-y | x---help | x-\?)
    echo "Usage: foss [ name ] [ repository_url ]"
    ;;
  x-*)
    dir="${FOSS}/${1}"
    if [ ! -d $dir ] ; then
      repo=${2:?"Not found locally. Give repo URL as second argument"}
    fi
    ;;
  esac

  if [ ! -d "$dir" -a -n "${repo}" ] ; then
    cd ${FOSS}
    git clone "${repo}" "${dir}"
  fi
  pushd $dir
}

# See https://unix.stackexchange.com/a/692303/566094
_foss_compgen_filenames() {
    local cur="$1"
    local FOSS_DIR=$HOME/foss/

    # Files, excluding directories:
    grep -v -F -f <(compgen -d -P ^ -S '$' -- $FOSS_DIR"$cur") \
        <(compgen -f -P ^ -S '$' -- $FOSS_DIR"$cur") |
        sed -e 's|^\^'$FOSS_DIR'||' -e 's/\$$/ /'

    # Directories:
    compgen -d -S / -- $FOSS_DIR"$cur" | sed -e 's|'$FOSS_DIR'||'
}

_foss_complete() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=( $(_foss_compgen_filenames "$cur") )
}
complete -o nospace -F _foss_complete foss

crashed () {
  find ~ -name '*.sw[po]' | xargs rm
  rm ~/*/tmp/pids/*
  rm -f ~/jarvis/.zeus.sock
  rm ~/.mozilla/firefox/*/.parentlock
}

clip () {
  case `uname -a` in
  *Darwin*) pbcopy ;;
  * ) xclip -i -selection clipboard ;;
  esac
}

fn_exists () {
  declare -f -F $1 > /dev/null
  return $?
}

export i3="integration3"

west() {
  local env cluster_prefix
  env=${1:-uat}
  cluster_prefix=${2:-service-}
  case ${env} in
  i3)   env="integration3"
  esac
  # use-cluster runs aws eks update-kubeconfig (IAM auth + current context); no kube-setup.
  aws-environment "${env}" platform --region us-west-2 &&
    use-cluster "${cluster_prefix}" us-west-2
}

east() {
  local env cluster_prefix
  env=${1:-uat}
  cluster_prefix=${2:-service-}
  case ${env} in
  i3)   env="integration3"
  esac
  aws-environment "${env}" platform --region us-east-1 &&
    use-cluster "${cluster_prefix}" us-east-1
}

dod() {
  local cluster_prefix=${1:-service-}
  aws-environment "dod" --region us-east-1 &&
    use-cluster "${cluster_prefix}" us-east-1
}

# Point kubectl at the sole EKS cluster in $region whose name starts with $prefix.
# Requires current AWS credentials for that account. Fails if 0 or 2+ clusters match.
use-cluster() {
  local prefix region json matches=() name
  prefix="${1:?usage: use-cluster <name-prefix> [region]}"
  region="${2:-${AWS_REGION:-${AWS_DEFAULT_REGION}}}"
  if [[ -z "$region" ]]; then
    echo "use-cluster: set AWS_REGION or pass region as second argument" >&2
    return 1
  fi
  json=$(aws eks list-clusters --region "$region" --output json) || {
    echo "use-cluster: aws eks list-clusters failed" >&2
    return 1
  }
  while IFS= read -r name; do
    [[ -n "$name" ]] && matches+=("$name")
  done < <(jq -r --arg p "$prefix" '.clusters[] | select(startswith($p))' <<<"$json")

  if ((${#matches[@]} == 0)); then
    echo "use-cluster: no cluster in ${region} starts with ${prefix}" >&2
    return 1
  fi
  if ((${#matches[@]} > 1)); then
    echo "use-cluster: ambiguous prefix ${prefix} (${#matches[@]} clusters):" >&2
    printf '  %s\n' "${matches[@]}" >&2
    return 1
  fi
  mkdir -p "${HOME}/.kube"
  aws eks update-kubeconfig --name "${matches[0]}" --region "$region" || return 1
  [[ -f "${HOME}/.kube/config" ]] && chmod go-rw "${HOME}/.kube/config"
  export KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/config}"
}

dpw() {
  env=${1:-uat}
  case ${env} in
  i3)   env="integration3"
  esac
  pushd ${IH_HOME}/DPW/terraforming/grnds-environments/${env}
}
