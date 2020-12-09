# TODO: Reconcile all the k8s & docker aliases.

alias k=kubectl
aws-environment () {
  gr::aws_environment::main "$@";
  if [ $# -gt 0 ]; then
    export KUBECONFIG=~/.kube/config.$AWS_ENVIRONMENT
    test -f $KUBECONFIG || aws eks update-kubeconfig --name "$AWS_ENVIRONMENT-eks-cluster" --kubeconfig $KUBECONFIG
  fi
}

# Make idempotent!
k_login_prep() {
  gr-load-root-key
  vpnme
}

k_cached_instances() {
  minute=$(date +%M)
  cache_minute=$(( $minute / 5))
  prefix="/tmp/_k_cached_instances_"
  cache_instance_file="${prefix}${cache_minute}"

  if [ -f "${cache_instance_file}" ] ; then
    cat "${cache_instance_file}"
  else
    rm "${prefix}"*
    gr-list-instances | tee "${cache_instance_file}"
  fi
}

k_login_node() {
  # Number nodes by sorted IP address, so you can log into each of them, indexing starting at 0
  bastion_host=$(k_cached_instances | grep bast | awk '{ print $4 }')
  cluster_hosts=$(k_cached_instances | grep 'eks-.*-default' | awk '{print $4}')
  cluster_hosts=(${cluster_hosts})

  index=${1:-0}

  destination=${cluster_hosts[${index}]}

  echo ssh ec2-user@${destination}  -o "proxycommand ssh -W %h:%p ${bastion_host}"
}
