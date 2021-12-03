jwt_get_token() {
  local domain=uat
  local user=
  local password=
  local client=
  local client_secret=

  curl --request POST \
    --url 'https://auth.uat.grandrounds.com/oauth/token' \
    --header 'content-type: application/x-www-form-urlencoded' \
    --data grant_type=password \
    --data-urlencode username=joshua.escribano+walmart@grnds.com  \
    --data password=password1! \
    --data audience=grandrounds \
    --data 'client_id=3KJW8tSl3NHF4o8I6SCecNnrJBNjDoUR' \
    --data client_secret=Yej8T0xfIZukGPLhavUO88TS9zidgByR9Fl1U-dgNJFpn0dOG-BBHwaBX_B7gP2U |\
  jq .access_token
}

jwt_parse_token() {
  local token=$1
  ruby -rJSON -rbase64 -rPP -e '
    token="'"${token}"'"
    header, payload, signature = token.split(".")

    header_hash = JSON.parse(Base64.decode64(header))
    payload_hash = JSON.parse(Base64.decode64(payload))

    puts "JOSE Header:"
    PP.pp header_hash
    puts "Payload:"
    PP.pp payload_hash

    fail "No signature" unless signature.length >0
  '
}

curl-with-token() {
  local token=$1
  true # NOT WRITTEN YET, SEEMS LIKE WE NEED MORE STATE.
}
