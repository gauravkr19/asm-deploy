/*
gcloud services enable \
iam.googleapis.com \
cloudresourcemanager.googleapis.com \
compute.googleapis.com \
containerregistry.googleapis.com \
container.googleapis.com \
storage-component.googleapis.com \
logging.googleapis.com \
monitoring.googleapis.com \
serviceusage.googleapis.com \
meshca.googleapis.com \
stackdriver.googleapis.com \
meshconfig.googleapis.com \
meshtelemetry.googleapis.com \
cloudtrace.googleapis.com 
gcurl "https://serviceusage.googleapis.com/v1/projects/${PROJECT_NUMBER}/services?filter=state:DISABLED"
*/

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
  regional                 = false
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
  cluster_resource_labels  = { "mesh_id" : "proj-${data.google_project.project.number}" }
  network_policy             = true
  http_load_balancing        = false
  horizontal_pod_autoscaling = true  
  node_pools = [
    {
      name               = "butler-pool"
      node_count         = 2
      #node_locations     = "us-central1-b,us-central1-c"
      min_count          = 1
      max_count          = 4
      preemptible        = true
      machine_type       = "n1-standard-2"
      disk_size_gb       = 50
      disk_type          = "pd-standard"
      image_type         = "COS"
      auto_repair        = true    
    }
  ]
}

resource "null_resource" "get-credentials" {
 depends_on = [module.jenkins-gke.name] 
 provisioner "local-exec" {   
   command = "gcloud container clusters get-credentials ${module.jenkins-gke.name} --zone=${element((var.zones), 1)}"   
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

/*****************************************
  Jenkins Workload Identity
 *****************************************/
module "workload_identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version             = "14.3.0"
  project_id          = data.google_client_config.default.project
  name                = "jenkins-wi-${module.jenkins-gke.name}"
  namespace           = "default"
  use_existing_k8s_sa = false
}

# enable GSA to add and delete pods for jenkins builders
resource "google_project_iam_member" "cluster-dev" {
  project = data.google_client_config.default.project
  role    = "roles/container.developer"
  member  = module.workload_identity.gcp_service_account_fqn
}

data "google_client_config" "default" { }

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

data "local_file" "helm_chart_values" {
  filename = "${path.module}/values.yaml"
}
resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  #version   = "3.3.10"
  timeout    = 1200
  values     = [data.local_file.helm_chart_values.content]
  depends_on = [
    kubernetes_secret.gh-secrets, 
    null_resource.get-credentials,
  ]
}


# #Anthos - Make this Anthos Cluster
# module "asm" {
#   source           = "terraform-google-modules/kubernetes-engine/google//modules/asm"

#   project_id       = data.google_client_config.default.project
#   cluster_name     = var.clusname
#   location         = module.jenkins-gke.location
#   cluster_endpoint = module.jenkins-gke.endpoint
#   asm_dir          = "asm-dir-${module.jenkins-gke.name}"
#   #depends_on       = [module.hub.cluster_name]
# }


# module "acm" {
# source           = "terraform-google-modules/kubernetes-engine/google//modules/acm"

#   project_id       = data.google_client_config.default.project
#   cluster_name     = var.clusname
#   location         = module.jenkins-gke.location
#   cluster_endpoint = module.jenkins-gke.endpoint
#   #depends_on       = [module.asm.cluster_name]

#   sync_repo        = "git@github.com:GoogleCloudPlatform/csp-config-management.git"
#   sync_branch      = "1.0.0"
#   policy_dir       = "foo-corp"
# }


# module "hub" {
# source           = "terraform-google-modules/kubernetes-engine/google//modules/hub"

#   project_id       = data.google_client_config.default.project
#   cluster_name     = var.clusname
#   location         = module.jenkins-gke.location
#   cluster_endpoint = module.jenkins-gke.endpoint
#   depends_on       = [helm_release.jenkins]
# }
