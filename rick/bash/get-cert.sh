get-cert () {
  # from https://serverfault.com/a/661982
  site=${1:?"Site"}
  echo | openssl s_client -showcerts -servername "${site}" -connect "${site}:443" 2>/dev/null | openssl x509 -inform pem -noout -text
}
