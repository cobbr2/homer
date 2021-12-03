# This sort of thing just doesn't work in MacOSx, at least after Big Sur.
# # Odd, never had to do this in Linux...
# ssh-agent-setup() {
#   eval $(ssh-agent)
#   ssh-add -K
# }
#
# # Not working cleanly, run yourself when necessary
# #ssh-agent-setup
#
# Magic from https://github.com/docker/for-mac/issues/4242#issuecomment-900749766
# forwarded from https://github.com/ChrisJohnsen/tmux-MacOSX-pasteboard/issues/78#issuecomment-899209930
export SSH_AUTH_SOCK=`launchctl asuser "${UID:-"$(id -u)"}" launchctl getenv SSH_AUTH_SOCK`
ssh-add -A 2>/dev/null
