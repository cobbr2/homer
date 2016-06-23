# sets up your readline environment so command line editing
# is sane. Well, sane for a vi user.
vimrl() {
  if [ ! -f ~/.vim_inputrc ] ; then
    # Yes, tabs are necessary here
    sed 's/^  *//' > ~/.vim_inputrc <<-MINIMUM
	"\e[A": history-search-backward
	"\e[B": history-search-forward
	"\e[C": forward-char
	"\e[D": backward-char
	set editing-mode vi
	MINIMUM
  fi

  set -o vi
  export INPUTRC=~/.vim_inputrc EDITOR=vim
}
