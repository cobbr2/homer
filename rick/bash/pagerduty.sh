# Idea is that you can copy from your PD alert,
# and get local shell variables for the label values.
#
# so if you had copied from PagerDuty the strings:
#
#  Labels:
#   - alertname = Nodes Not Ready
#   - grafana_folder = TNG
#   - node = ip-10-191-204-79.ec2.internal
#   - tng_environment = production
#   - tng_region = us-east-1
#  Annotations:
#
# and you pasted that in like:
# $ pd-variables <<FOO
# <paste>
# FOO
#
# you would immediately have as variables
# $ set
# alertname="Nodes Not Ready"
# grafana_folder="TNG"
# ...
#
# Given this, you can then automate runbooks like the ones for Nodes Not Ready

pd_labels_to_bash_assignments() {
  sed -n '
    /^ *- / {
     s/^ *- //
     s/ = /="/
     s/$/"/
     p
   }
  '
}

pd_variables() {
echo "Paste your buffer from PagerDuty here and then use CTRL-D"

eval $(pd_labels_to_bash_assignments)
}

instance_from_node() {
  eval $($GR_HOME/kore/bin/list-nodes | grep "/^$node/" | tee /dev/stderr | awk '/^'"${node}"'/ { print "instance=" $5 }')
}

pd_env() {
  aws-environment --region $tng_region $tng_environment platform
  kube-setup
}
