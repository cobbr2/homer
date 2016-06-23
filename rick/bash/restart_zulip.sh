
function twolip() {
  ps -ef | grep 'zulip' | grep -v 'grep' | awk '{ print $2}' | xargs --no-run-if-empty kill
  zulip --site http://ice.integration.grandrounds.com &
}
