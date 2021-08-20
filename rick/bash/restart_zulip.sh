
function twolip() {
  ps -ef | grep 'zulip' | grep -v 'grep' | awk '{ print $2}' | xargs -r kill
  zulip --site http://ice.integration.grandrounds.com &
}
