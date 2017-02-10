
function path_split {
  echo $PATH | tr ':' '\012'
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
  if ! path_has "${1}" ; then
    PATH="${PATH}:${1}"
  fi
}

path_push ~/engineering/bin
for setup in ~/engineering/bash/*.sh ; do
  . $setup
done

path_push ~/bin
for setup in ~/homer/rick/bash/*.sh ; do
  . $setup
done

if [ -n "$rvm_path" ] ; then
  cd $PWD # Get the .rvm_* files read
fi

export NVM_DIR="/home/rcobb/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

PATH="/home/rcobb/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="/home/rcobb/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="/home/rcobb/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"/home/rcobb/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=/home/rcobb/perl5"; export PERL_MM_OPT;
