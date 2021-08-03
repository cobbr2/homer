bashlog() {
  echo ${1} >>~/.bashlog
}

UNAME=$(uname)

case $UNAME in
Darwin*) RICK_OS=Darwin;;
[Uu]buntu)      RICK_OS=Linux ;;
*)      bashlog "Unrecognized OS ${UNAME}, assuming Linux"
        RICK_OS=Linux ;;
esac

export RICK_OS
