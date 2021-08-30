github-token-auth () {
  # Assumes formatted as
  #  export GITHUB_USER=...
  #  export GITHUB_TOKEN=...
  gpgenv ${HOME}/gpgs/git-tokens.gpg
  #export GITHUB_TOKEN=$(awk -F':' '{ print $2 }' ~/.npmrc | awk -F'=' '{ print $2 }')
}
