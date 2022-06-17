# pretty prompt for git repos, some links for those intersted in extra credit
# http://effectif.com/git/config
# http://sitaramc.github.com/2-command-line-usage/souped-up-bash-prompt.html
# http://zerowidth.com/blog/2008/11/29/command-prompt-tips.html
prompt_function() {
  local        BLUE='\[\033[0;34m\]'
  local         RED='\[\033[0;31m\]'
  local   LIGHT_RED='\[\033[1;31m\]'
  local       GREEN='\[\033[0;32m\]'
  local LIGHT_GREEN='\[\033[1;32m\]'
  local      YELLOW='\[\033[0;33m\]'
  local       WHITE='\[\033[1;37m\]'
  local  LIGHT_GRAY='\[\033[0;37m\]'
  local        GRAY='\[\033[1;30m\]'
  local       RESET='\[\033[0m\]'
  local TITLE_START='\[\033]0;'
  local   TITLE_END='\007\]'
  # PROMPT_COMMAND='echo -ne "\033]0;SOME TITLE HERE\007"'

  # previous_return_value=$?;
  # case $previous_return_value in
  #   0)
  #     prompt_color="${RESET}"
  #   ;;
  #   1)
  #     prompt_color="${LIGHT_RED}"
  #   ;;
  #   *)
  #     prompt_color="${LIGHT_YELLOW}"
  #   ;;
  # esac
  # use "${prompt_color}\$${RESET}" instead of "\$" below
  aws_env=$(aws-environment)
  aws_color_off='tput sgr 0'
  case "${aws_env}" in
    *production*)
      aws_color_on='tput setab 1' # Red
      ;;
    *dod*)
      aws_color_on='tput setab 172' # Orange
      ;;
    *uat*)
      aws_color_on='tput setab 3' # Yellow/orange
      ;;
    *integration3*)
      aws_color_on='tput setab 4' # Blue
      ;;
    *dev*)
      aws_color_on='tput sgr 0' # Nada
      ;;
    *)
      aws_color_on='tput setab 7' # Grey
      ;;
  esac

  case "${AWS_DEFAULT_REGION}" in
    us-east-1)
      region_arrow="→"
      ;;
    us-west-2)
      region_arrow="←"
      ;;
    *)
      region_arrow=":"
      ;;
  esac

  if test $(git status 2> /dev/null | grep -c :) -eq 0; then
    git_color="${GREEN}"
  else
    git_color="${RED}"
  fi
  #PS1="${RESET}\u@\h: \w${git_color}$(__git_ps1)${RESET}\$ "
  # I got lost too often that way, so moved the git stuff before the dir
  #PS1="${RESET}\u@\h:${git_color}$(__git_ps1)${RESET} \w\$ "
  local BRANCH=$(__git_ps1)
  local STATUS="${RESET}\[$($aws_color_on)\]\u@\h${region_arrow}${git_color}${BRANCH}${RESET} \w${TITLE_START}\w${TITLE_END}\[$($aws_color_off)\]"

  #echo $(( ${#BRANCH} + ${#PWD} ))
  if [[ $(( ${#BRANCH} + ${#PWD} )) -lt 100 ]] ; then
    PS1="${STATUS}\$ "
  else
    PS1="
${STATUS}
\$ "
  fi
}
PROMPT_COMMAND=prompt_function
