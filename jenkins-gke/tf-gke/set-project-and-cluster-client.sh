DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

unset KUBECONFIG

gcloud config set project ${PROJECT_ID}

gcloud container clusters get-credentials jenkins-gke --region ${ZONE} --project ${PROJECT_ID}
