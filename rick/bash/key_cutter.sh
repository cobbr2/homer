export IPSEC_SECRETS_FILE=/etc/ipsec.secrets

function key_cutter() {
  echo "You'll probably need two ^Ds" >/dev/tty
  echo "\"$(gpg -o - -i -)\"" | clip
  sudo vim /etc/ipsec.secrets
  sudo ipsec restart
}
