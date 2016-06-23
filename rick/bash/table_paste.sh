# Just getting started here, nothing to see.

function mysql_table () {
  xsel --clipboard | tail -n +2 | head -n -1 | perl -pe 's/^\+/|:/g; s/\+$/:|/g; s/-\+-/:|:/g;' | xsel --clipboard -
}
