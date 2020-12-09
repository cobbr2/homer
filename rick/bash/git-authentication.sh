github-token-auth () {
  #export GITHUB_TOKEN=$(awk -F':' '{ print $2 }' ~/.npmrc | awk -F'=' '{ print $2 }')
  export GITHUB_TOKEN="a5d7e5e45e49e59b3b97e609c43bb21cff2d357a"
  export GITHUB_USER=cobbr2
}
