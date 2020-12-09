set tabstop=8
set shiftwidth=2
" set background=dark
set expandtab
set autoindent
set title
" For us traditional ctrl-] ctrl-t TAGS guys..., though TListToggle
" comes in handy too, and is added later. Maintained with the 'rtags' shell
" function.
"set tags=TAGS;,tags;,./TAGS,./TAGS.uncommon,./tags,$HOME/TAGS,$HOME/TAGS.uncommon
set tags=TAGS;,tags;
set wildmode=longest:full
set wildmenu
set modelines=4

" < Handle whitespace issues:
" Show tabs as odd character, same with trailing spaces or tabs.
set list lcs=tab:·⁖,trail:¶
" Remove trailing whitespace on save for files I care about
autocmd FileType rb,ruby,slim,txt,c,cpp,java,php,python,py,markdown,yml,tf,sh,scala,sql autocmd BufWritePre <buffer> :%s/\s\+$//e
" >

" No Modula 2 for me!
autocmd BufNewFile,BufRead *.md set filetype=markdown

:syntax enable
:retab

" FIXME: Get ruby % matching right.
" from http://items.sjbach.com/319/configuring-vim-right
" Trying to get %-matching to work right for ruby. Also installed
" ftplugin/ruby.vim from 
" http://www.vim.org/scripts/script.php?script_id=303
" still no-workie
" I ended up adding matchit in as a plugin using :help matchit (it's
" an example), and now have that plugin -- but still no ruby.
" runtime macros/matchit.vim

" Add pathogen so more plugins (especially the slim colorer) work:
" https://github.com/tpope/vim-pathogen
execute pathogen#infect()

" From Jason Snell's CC .vimrc:

autocmd BufReadPost *
      \ if ! exists("g:leave_my_cursor_position_alone") |
      \     if line("'\"") > 0 && line ("'\"") <= line("$") |
      \         exe "normal g'\"" |
      \     endif |
      \ endif

"set background=dark

" Copy visual selection to osx clipboard
"map <C-c> ygv:!pbcopy<CR>ugv
" Copy visual to X windows clipboard. Use -selection clipboard to 
" go to the Gnome clipboard later when unifying keystrokes.
map <C-c> ygv:!xclip -i<CR>ugv

" kill ring
map <leader>k :YRShow<CR>

" Window movement
map <C-J> <C-W>j<C-W>_
map <C-K> <C-W>k<C-W>_

" Autocompleting
setlocal omnifunc=syntaxcomplete#Complete

" FuzzyFinderText
map <leader>j :FufJumpList<CR>
map <leader>f :FufFile<CR>
map g:fuf_keyOpenTabpage <CR>

map <leader>t :TlistToggle<CR>
let Tlist_GainFocus_On_ToggleOpen = 1

" tab nav
map <S-h> :tabp<CR>
map <S-l> :tabn<CR>

" Allow backspace to erase stuff (syntax error on my vim)
"set backspace+=indent,eol,start 

" Custom keys
map <leader>q :q<CR>
map <leader>w :w<CR>
map <leader>wq :wq<CR>

" Try for automatic indenting on XML files while working on APIs, etc.
" OTOH: *does* change the file on writing, so be careful.
" au FileType xml exe ":silent 1,$!XMLLINT_INDENT='    ' xmllint --encode UTF-8 --format --recover - 2>/dev/null"

cnoremap <Tab> <C-L><C-D>

