alias k8='kubectl'

alias k8_pods='k8 get pods -n data-eng-airflow-workers | grep Running'

function k8_auth() {
  cluster=${1:-"service-dev"}
  role=${2:-"platform"}

  aws-environment "${cluster}" "${role}" && aws eks update-kubeconfig --name "${cluster}-eks-cluster"
}

function k8_pods_enter() {
  k8 exec -it "$1" -n data-eng-airflow-workers  -- /bin/bash
}
export -f k8_pods_enter

function k8_pods_image() {
  k8 get pods -n data-eng-airflow-workers "$1" -o json | jq '.status.containerStatuses[] | { "image": .image, "imageID": .imageID }'
}
export -f k8_pods_image
