_jira_token=$(security find-generic-password -s "jira-api" -w 2>/dev/null)
if [[ -n "$_jira_token" ]]; then
  export JIRA_API_TOKEN="$_jira_token"
  export JIRA_USERNAME=$(security find-generic-password -s "jira-api" 2>/dev/null \
    | awk -F'"' '/"acct"/{print $4}')
fi
unset _jira_token
