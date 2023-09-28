function stripansi() {
  # From Adam Katz, https://superuser.com/a/1388860
  perl -pe '
    s/\e\[[\x30-\x3f]*[\x20-\x2f]*[\x40-\x7e]//g;
    s/\e[PX^_].*?\e\\//g;
    s/\e\][^\a]*(?:\a|\e\\)//g;
    s/\e[\[\]A-Z\\^_@]//g;' "$@"
}
