sdiff() {
    diff -y -W $(tput cols) "$1" "$2" | less -R
}
