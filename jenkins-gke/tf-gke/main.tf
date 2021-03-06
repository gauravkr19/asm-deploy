/*****************************************
  Activate Services in Jenkins Project
 *****************************************/
module "project-services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"

  project_id  = data.google_client_config.default.project
  disable_services_on_destroy = false
  activate_apis = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "container.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "anthos.googleapis.com",
    "cloudtrace.googleapis.com",
    "meshca.googleapis.com",
    "meshtelemetry.googleapis.com",
    "meshconfig.googleapis.com",
    "iamcredentials.googleapis.com",
    "gkeconnect.googleapis.com",
    "gkehub.googleapis.com",
    "monitoring.googleapis.com",
    "anthosconfigmanagement.googleapis.com",
    "logging.googleapis.com"
  ]
}

# Network Resources for Jenkins Cluster
resource "google_compute_network" "vpc" {
  name                    = "jenkins-vpc"
  project                 = var.project_id
  auto_create_subnetworks = "false"
  depends_on              = [module.project-services.project_id]  
}
resource "google_compute_subnetwork" "subnet" {
  name          = "jenkins-subnet"
  region        = var.region
  project       = var.project_id
  network       = google_compute_network.vpc.name
  ip_cidr_range = var.subnet_cidr

  secondary_ip_range {
    range_name    = "pod-cidr-name"
    ip_cidr_range = var.ip_cidr_subnet_pods
  }
  secondary_ip_range {
    range_name    = "service-cidr-name"
    ip_cidr_range = var.ip_cidr_subnet_services
  }  
}

data "google_client_config" "default" { }
data "google_project" "project" {
  project_id = var.project_id
}

/*****************************************
  Jenkins GKE
 *****************************************/
module "jenkins-gke" {
  source                   = "terraform-google-modules/kubernetes-engine/google//modules/beta-public-cluster/"
  version                  = "13.0.0"
  project_id               = data.google_client_config.default.project
  name                     = var.clusname
  regional                 = true
  region                   = var.region
  zones                    = var.zones
  network                  = google_compute_network.vpc.name
  subnetwork               = google_compute_subnetwork.subnet.name
  ip_range_pods            = var.ip_range_pods
  ip_range_services        = var.ip_range_services
  logging_service          = "logging.googleapis.com/kubernetes"
  monitoring_service       = "monitoring.googleapis.com/kubernetes"
  remove_default_node_pool = true
  service_account          = "create"
  identity_namespace       = "${data.google_client_config.default.project}.svc.id.goog"
  node_metadata            = "GKE_METADATA_SERVER"
  network_policy             = true
  http_load_balancing        = false
  horizontal_pod_autoscaling = true
  release_channel            = "REGULAR"
  node_pools = [
    {
      name               = "butler-pool"
      #node_count         = 2
      #node_locations     = "us-central1-b,us-central1-c"
      min_count          = 2
      max_count          = 3
      preemptible        = true
      machine_type       = "n1-standard-4"
      disk_size_gb       = 50
      disk_type          = "pd-standard"
      image_type         = "COS"
      auto_repair        = true    
      auto_upgrade       = true   
    }
  ]
}

resource "null_resource" "get-credential" {
 depends_on = [module.jenkins-gke] 
 provisioner "local-exec" {   
   command = "gcloud container clusters get-credentials ${module.jenkins-gke.name} --zone=${var.region}"
  }
}

module "kubectl-ns" {
  source = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"

  project_id              = var.project_id
  cluster_name            = var.clusname
  cluster_location        = var.region
  kubectl_create_command  = "kubectl apply -f ${path.module}/asm-ns.yaml"
  kubectl_destroy_command = "kubectl delete ns asm-system"
  module_depends_on       = [null_resource.get-credential]
}

# resource "null_resource" "patch-ns" {
#   depends_on = [module.kubectl-ns]
#   provisioner "local-exec" {
#     command = <<EOF
# kubectl patch ns asm-system --type='json' -p='[{"op": "add", "path": "/metadata/annotations/gke.io~1cluster", "value": "gke://${var.project_id}/${var.region}/${module.jenkins-gke.name}"}]'
# EOF
#   }
# }

resource "kubernetes_namespace" "istio" {
  depends_on = [module.jenkins-gke.name] 
  metadata {
     name = "istio-system"
  }
}

/*****************************************
  Jenkins Workload Identity
 *****************************************/
module "workload_identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version             = "13.0.0"
  project_id          = data.google_client_config.default.project
  name                = "jenkins-wi-${module.jenkins-gke.name}"
  namespace           = "default"
  use_existing_k8s_sa = false
}

/*****************************************
  K8S secrets for GH
 *****************************************/
resource "kubernetes_secret" "gh-secrets" {
  metadata {
    name = "github-secrets"
  }
  data = {
    github_username = var.github_username
    github_repo     = var.github_repo
    github_token    = var.github_token
  }
}

/*****************************************
  K8S secrets for configuring K8S executers
 *****************************************/
resource "kubernetes_secret" "jenkins-secrets" {
  metadata {
    name = var.jenkins_k8s_config
  }
  data = {
    project_id          = data.google_client_config.default.project
    kubernetes_endpoint = "https://${module.jenkins-gke.endpoint}"
    ca_certificate      = module.jenkins-gke.ca_certificate
    jenkins_tf_ksa      = module.workload_identity.k8s_service_account_name
  }
}

/*****************************************
  IAM Bindings GKE SVC
 *****************************************/
# allow GKE to pull images from GCR
resource "google_project_iam_member" "gke" {
  project = data.google_client_config.default.project
  role    = "roles/storage.objectViewer"

  member = "serviceAccount:${module.jenkins-gke.service_account}"
}

# enable GSA to add and delete pods for jenkins builders
resource "google_project_iam_member" "cluster-dev" {
  project = data.google_client_config.default.project
  role    = "roles/container.developer"
  member  = module.workload_identity.gcp_service_account_fqn
}

/*****************************************
  Grant Jenkins SA Permissions to store
  TF state for Jenkins Pipelines
 *****************************************/
resource "google_storage_bucket_iam_member" "tf-state-writer" {
  bucket = var.tfstate_gcs_backend
  role   = "roles/storage.admin"
  member = module.workload_identity.gcp_service_account_fqn
}

/*****************************************
  Grant Jenkins SA Permissions project editor
 *****************************************/
  resource "google_project_iam_member" "jenkins-project" {
    project = data.google_client_config.default.project
    role    = "roles/editor"
    member = module.workload_identity.gcp_service_account_fqn
  }

/*****************************************
  SA for ASM
 *****************************************/
resource "google_service_account" "asm" {
  depends_on = [module.acm-jenkins.wait]
  account_id   = "asm-svc-sa"
  display_name = "My Service Account"
}
resource "google_project_iam_member" "asmbind" {
  project = data.google_client_config.default.project
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.asm.email}"
}
resource "google_service_account_key" "asm_credentials" {
  service_account_id = google_service_account.asm.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}
resource "local_file" "cred_asm" {
  content  = "${base64decode(google_service_account_key.asm_credentials.private_key)}"
  filename = "${path.module}/asm-credentials.json"
}
resource "null_resource" "get-credentials" {
 depends_on = [local_file.cred_asm] 
 provisioner "local-exec" {   
   command = "gcloud container clusters get-credentials ${module.jenkins-gke.name} --zone=${var.region}"
  }
}
##### SA Key for ACM #######
resource "google_service_account" "acm" {
  account_id   = "anthos-svc-acm-sa"
  display_name = "SA for ACM"
}
resource "google_project_iam_member" "acmbind" {
  project = data.google_client_config.default.project
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.acm.email}"
}
resource "google_service_account_key" "acm_credentials" {
  service_account_id = google_service_account.acm.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}
resource "local_file" "cred_acm" {
  content  = "${base64decode(google_service_account_key.acm_credentials.private_key)}"
  filename = "${path.module}/acm-credentials.json"
}
resource "time_sleep" "wait_10s" {
  depends_on = [local_file.cred_acm]
  create_duration = "10s"
}

#Anthos - Make GKE Anthos Cluster
module "asm-jenkins" {
  source           = "terraform-google-modules/kubernetes-engine/google//modules/asm"
  version          = "15.0.0"
  asm_version      = var.asm_version
  project_id       = data.google_client_config.default.project
  cluster_name     = var.clusname
  location         = module.jenkins-gke.location
  cluster_endpoint = module.jenkins-gke.endpoint
  enable_all            = false
  enable_cluster_roles  = true
  enable_cluster_labels = false
  enable_gcp_apis       = false
  enable_gcp_iam_roles  = false
  enable_gcp_components = true
  enable_registration   = false
  managed_control_plane = false
  service_account       = google_service_account.asm.email
  key_file              = "${path.module}/asm-credentials.json"
  options               = ["envoy-access-log,egressgateways"]
  skip_validation       = true
  outdir                = "./${module.jenkins-gke.name}-outdir-${var.asm_version}"
}

resource "time_sleep" "wait_20s" {
   depends_on = [module.acm-jenkins.wait]
  create_duration = "20s"
}

resource "google_gke_hub_membership" "membership" {
  depends_on    = [
    module.acm-jenkins.wait,
    time_sleep.wait_20s
    ]
  membership_id = "anthos-gke"
  project       = var.project_id
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/projects/${var.project_id}/locations/${var.region}/clusters/${var.clusname}"
    }
  }
  description = "Anthos Cluster Hub Registration"
  provider = google-beta
}

resource "time_sleep" "wait_2m" {
  depends_on = [google_gke_hub_membership.membership]
  create_duration = "2m"
}

module "acm-jenkins" {
  source           = "github.com/terraform-google-modules/terraform-google-kubernetes-engine//modules/acm"

  project_id       = data.google_client_config.default.project
  cluster_name     = var.clusname
  location         = module.jenkins-gke.location
  cluster_endpoint = module.jenkins-gke.endpoint
  service_account_key_file = "${path.module}/acm-credentials.json"

  operator_path    = "config-management-operator.yaml"
  sync_repo        = var.acm_repo_location
  sync_branch      = var.acm_branch
  policy_dir       = var.acm_dir
}


#### Jenkins Deployment ####
# resource "null_resource" "get-credentials" {
#  depends_on = [
#    module.asm-jenkins.asm_wait,
#    module.acm-jenkins.wait,
#  ] 
#  provisioner "local-exec" {   
#    command = "gcloud container clusters get-credentials ${module.jenkins-gke.name} --zone=${var.region}"
#   }
# }

# data "local_file" "helm_chart_values" {
#   filename    = "${path.module}/values.yaml"
# }
# resource "helm_release" "jenkins" {
#   name       = "jenkins"
#   repository = "https://charts.jenkins.io"
#   chart      = "jenkins"
#   #version   = "3.3.10"
#   timeout    = 600
#   values     = [data.local_file.helm_chart_values.content]
#   depends_on = [
#     kubernetes_secret.gh-secrets, 
#     null_resource.get-credentials,
#     data.local_file.helm_chart_values,
#     module.asm-jenkins.asm_wait,
#     module.acm-jenkins.wait,
#   ]
# }

# resource "null_resource" "previous" {}
# resource "time_sleep" "wait_2m" {
#   depends_on = [null_resource.previous]
#   create_duration = "2m"
# }

################ END ################

# #Anthos - Make GKE Anthos Cluster
# module "hub" {
#   source                  = "terraform-google-modules/kubernetes-engine/google//modules/hub"
#   project_id              = data.google_client_config.default.project
#   location                = module.jenkins-gke.location
#   cluster_name            = var.clusname
#   cluster_endpoint        = module.jenkins-gke.endpoint
#   gke_hub_membership_name = var.clusname
#   use_existing_sa         = true
#   gke_hub_sa_name         = google_service_account.hubsa.account_id
#   sa_private_key          = google_service_account_key.hubsa_credentials.private_key
#   module_depends_on       = var.module_depends_on
# }
