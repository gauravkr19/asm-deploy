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

data "google_client_config" "default" { }
data "google_project" "project" {
  project_id = var.project_id
}

# resource "kubernetes_cluster_role_binding" "user" {
#   metadata {
#     name = "terraform-example"
#   }
#   role_ref {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "ClusterRole"
#     name      = "cluster-admin"
#   }
#   subject {
#     kind      = "User"
#     name      = "${var.currentuser}"
#     api_group = "rbac.authorization.k8s.io"
#   }
# }

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
  cluster_resource_labels  = { "mesh_id" : "proj-${data.google_project.project.number}" }
  network_policy             = true
  http_load_balancing        = false
  horizontal_pod_autoscaling = true  
  node_pools = [
    {
      name               = "butler-pool"
      #node_count         = 2
      #node_locations     = "us-central1-b,us-central1-c"
      min_count          = 4
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

 module "hub" {
 source           = "terraform-google-modules/kubernetes-engine/google//modules/hub"

   project_id                        = data.google_client_config.default.project
   cluster_name                      = var.clusname
   location                          = module.jenkins-gke.location
   cluster_endpoint                  = module.jenkins-gke.endpoint
   gke_hub_membership_name           = "primary"
   #gke_hub_sa_name                   = "primary"
   module_depends_on                 = var.module_depends_on
 }

#####--zone=${element(jsonencode(var.zones), 0)}" 
#  resource "null_resource" "get-credentials" {
#   #depends_on = [module.jenkins-gke.name] 
#   provisioner "local-exec" {   
#     command = "gcloud container clusters get-credentials ${module.jenkins-gke.name} --zone=${var.region}"
#    }
#  }

# data "local_file" "helm_chart_values" {
#   filename = "${path.module}/values.yaml"
# }
# resource "helm_release" "jenkins" {
#   name       = "jenkins"
#   repository = "https://charts.jenkins.io"
#   chart      = "jenkins"
#   #version   = "3.3.10"
#   timeout    = 1200
#   values     = [data.local_file.helm_chart_values.content]
#   depends_on = [
#     kubernetes_secret.gh-secrets, 
#     null_resource.get-credentials,
#   ]
# }