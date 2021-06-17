/*****************************************
  Google Provider Configuration
 *****************************************/
provider "google" {
  project = var.project_id
  region  = var.region
  #credentials = "${file("sakey.json")}"
}

/*****************************************
  Kubernetes provider configuration
 *****************************************/
provider "kubernetes" {
  #version                = "~> 1.10"
  load_config_file       = false
  host                   = module.jenkins-gke.endpoint
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.jenkins-gke.ca_certificate)
}

/*****************************************
  Helm provider configuration
 *****************************************/
module "gke_auth" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  #version = "~> 9.1"

  project_id   = data.google_client_config.default.project
  cluster_name = module.jenkins-gke.name
  location     = module.jenkins-gke.location
}

provider "helm" {
  kubernetes {
    //load_config_file       = false
    config_path            = "~/.kube/config"
    cluster_ca_certificate = module.gke_auth.cluster_ca_certificate
    host                   = module.gke_auth.host
    token                  = module.gke_auth.token
  }
}
