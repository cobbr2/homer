function next_example() {
  name=$1
  dir=~/golang/$name
  mkdir $dir
  cd $dir
  xclip -o -selection clipboard > $name.go
  vi $name.go
}

function next_run() {
  name=$1
  dir=~/golang/$name
  if [ "${PWD}" != "${dir}" ] ; then
    cd $dir
  fi
  go run $name.go
}
