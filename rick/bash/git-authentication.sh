github-token-auth () {
  # Assumes formatted as
  #  export GITHUB_USER=...
  #  export GITHUB_TOKEN=...
  gpgenv ${HOME}/gpgs/git-tokens.gpg
}

github-token-auth
