# Use  docker rs:latest detect --source="/path" -v >_gitleaks.latest
#
# Use `gitleaks detect >_results` in the directory you want to analyze.
gitleaks() {
  command="${1}"
  shift
  docker run -v ${PWD}:/path zricethezav/gitleaks:latest "${command}" --source="/path" "$@"
}
