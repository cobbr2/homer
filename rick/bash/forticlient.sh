#!/bin/sh
#
#/opt/forticlient-sslvpn/64bit/./forticlientsslvpn_cli --help
#usage:/opt/forticlient-sslvpn/64bit/./forticlientsslvpn_cli [--proxy proxyaddress:proxyport] --server vpnserveraddress:vpnport [--proxyuser proxyuser] [--vpnuser vpnuser] [--pkcs12 pkcs12path] [--keepalive] 
# Tried to use expect to enter passwords, but it ended up taking more time than my box had.
#
# So it's GUI for now.

function forticlient() {
  /opt/forticlient-sslvpn/64bit/forticlientsslvpn &
}
