# pretty prompt for git repos, some links for those intersted in extra credit
# http://effectif.com/git/config
# http://sitaramc.github.com/2-command-line-usage/souped-up-bash-prompt.html
# http://zerowidth.com/blog/2008/11/29/command-prompt-tips.html

# Skip prompt customization when running in Cursor Agent
if [ -n "$CURSOR_AGENT" ] || [ -n "$CURSOR_TRACE_ID" ]; then
  # Absolute minimum prompt for Cursor Agent to avoid parsing issues
  PS1='$ '
  return 0
fi

prompt_function() {
  # SGR via _colorize / red / green / …; _COLORIZE_PS1 wraps escapes for PS1.
  # \u \h \w in arguments stay literal through $(…) and are expanded when bash
  # draws the prompt (not inside _colorize).
  export _COLORIZE_PS1=1

  local aws_env="${AWS_ENVIRONMENT}" aws_sgr
  case "${aws_env}" in
    *production*)
      aws_sgr='41;1;37' # red bg, bold white fg (was tput setab 1 + setaf 255)
      ;;
    *dod*)
      aws_sgr='48;5;172' # orange (tput 172)
      ;;
    *uat*)
      aws_sgr='43' # yellow bg
      ;;
    *integration3*)
      aws_sgr='44;1;37' # blue bg, bold white fg
      ;;
    *dev*)
      aws_sgr='0'
      ;;
    *)
      aws_sgr='47;30' # grey bg, black fg (was setab 7)
      ;;
  esac

  case "${AWS_REGION}" in
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

  local BRANCH git_styled TITLE_START TITLE_END STATUS
  local k8s_raw k8s_short k8s_sgr k8s_indic=""

  BRANCH=$(__git_ps1)
  # Tradeoff: by not going red for untracked files, this is fast
  # enough to run in "potluck".
  if [[ -z "$(git status --porcelain -uno 2>/dev/null)" ]]; then
    git_styled="$(green "${BRANCH}")"
  else
    git_styled="$(red "${BRANCH}")"
  fi

  # Read current-context directly from kubeconfig — avoids spawning the full kubectl
  # binary (~250ms) every prompt paint. For EKS contexts (created by aws eks
  # update-kubeconfig) the context name IS the cluster ARN, so this gives the
  # same color-coding result. Non-EKS contexts with aliased names (e.g.
  # "production-us-east-1") also work because the color case-statement uses broad
  # globs (*production*, *uat*, etc.) that match context names just as well.
  local _kubeconfig="${KUBECONFIG%%:*}"
  _kubeconfig="${_kubeconfig:-$HOME/.kube/config}"
  k8s_raw=$(awk '/^current-context:/{print $2; exit}' "$_kubeconfig" 2>/dev/null)
  if [[ -n "$k8s_raw" ]]; then
    if [[ "$k8s_raw" == arn:aws:eks:* ]]; then
      k8s_short="${k8s_raw##*/}"
    else
      k8s_short="$k8s_raw"
    fi
    case "$k8s_short" in
      service-*)      k8s_sgr='42;30' ;;       # green bg / black fg (light terminals)
      compute*)       k8s_sgr='43;30' ;;       # yellow bg / black fg
      observability*) k8s_sgr='44;97' ;;      # blue bg / white fg
      management*)    k8s_sgr='41;1;37' ;;   # red bg / bold white fg
      *)              k8s_sgr='48;5;208;30' ;; # orange(ish) bg / black fg
    esac
    k8s_indic="$(_colorize "${k8s_sgr}" " ${k8s_short}")"
  fi

  TITLE_START="$(ps1_title_start)"
  TITLE_END="$(ps1_title_end)"
  STATUS="$(plain)$(_colorize "${aws_sgr}" "\u@\h${region_arrow}")${k8s_indic}${git_styled} \w${TITLE_START}\w${TITLE_END}"

  PS1="${STATUS}
\$ "

  unset _COLORIZE_PS1
}
PROMPT_COMMAND=prompt_function

unprompt() {
  PROMPT_COMMAND=''
  PS1="$ "
}
