alias k8='kubectl'

alias k8_pods='k8 get pods -n data-eng-airflow-workers | grep Running'

alias k8_auth='aws-environment platform-dev platform && aws eks update-kubeconfig --name platform-dev-eks-cluster'

function k8_pods_enter() {
  k8 exec -it "$1" -n data-eng-airflow-workers  -- /bin/bash
}
export -f k8_pods_enter

function k8_pods_image() {
  k8 get pods -n data-eng-airflow-workers "$1" -o json | jq '.status.containerStatuses[] | { "image": .image, "imageID": .imageID }'
}
export -f k8_pods_image
