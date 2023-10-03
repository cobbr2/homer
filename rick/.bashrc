# Because Apple is a pain
export BASH_SILENCE_DEPRECATION_WARNING=1

export GR_HOME=~/ih_home

function path_split {
  echo $PATH | tr ':' '\012'
}

# Can't pipeline and have the end of a pipeline set a shell var,
# since pipelines run in subshells. So to easily support path_rm,
# can't split it into `path_split | grep -v | path_set`; have to do
# it the non-unixy way, AFAICT
function path_rm {
  pattern=${@:?"You must provide pattern(s) to remove; will automatically be grep -v"}
  new_path=$(path_split | grep -v "${@}" | tr '\012' ':')
  PATH="${new_path}"
}

function path_has {
  path_split | egrep '^'"${1}"'$' >/dev/null
}

function path_push {
  if ! path_has "${1}" ; then
    if path_split | fgrep '/.rvm/' > /dev/null ; then
      rvm_paths=$(path_split | fgrep '/.rvm/')
      non_rvm_paths=$(path_split | fgrep -v '/.rvm/')
      NEW_PATH=$(echo "${rvm_paths}
${1}
${non_rvm_paths}" | tr '\012' ':')
    else
      NEW_PATH="${1}:${PATH}"
    fi
    PATH="${NEW_PATH}"
  fi
}

function path_append {
  path_has "${1}" || PATH="${PATH}:${1}"
}

function timed_source {
  #echo -n "$@: " && time . "$@"
  . "$@"
}

path_push ~/bin

# Set up for v2 bash-completions (MacOS only):
# See https://discourse.brew.sh/t/bash-completion-2-vs-brews-auto-installed-bash-completions/2391/3?u=danemacmillan
#export BASH_COMPLETION_COMPAT_DIR="/usr/local/etc/bash_completion.d"
#timed_source "/usr/local/etc/profile.d/bash_completion.sh"

for setup in ~/homer/rick/bash/*.sh ; do
  #echo -n "$setup "
  . $setup
  #echo "$setup done"
done

export NVM_DIR="${HOME}/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

PATH="${HOME}/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="${HOME}/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="${HOME}/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"${HOME}/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=${HOME}/perl5"; export PERL_MM_OPT;

timed_source $HOME/.asdf/asdf.sh

timed_source $HOME/.asdf/completions/asdf.bash

# This loads the Included Health shell augmentations into your interactive shell
timed_source "$HOME/.ih/augment.sh"
