" Additional pieces just for me
:au BufNewFile,BufRead *.lookml          setf yaml
" Dropped in here for python work... probably should capture in a bundle:
:au BufNewFile,BufRead *.py  set
  \ tabstop=4
  \ softtabstop=4
  \ shiftwidth=4
  \ textwidth=119
  \ expandtab
  \ autoindent
  \ fileformat=unix
