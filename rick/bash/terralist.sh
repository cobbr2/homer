terralist-login() {
  export TF_TOKEN_terralist_includedhealth_com=$(tng params get --service platform-api terralist-includedhealth-token)
  export TF_TOKEN_terralist_uat_includedhealth_com=$(tng params get --service platform-api terralist-uat-includedhealth-token)
}
