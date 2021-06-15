variable "module_depends_on" {
  default = [
    "google_project_iam_member.gke", 
    "google_project_iam_member.cluster-dev", 
    "google_project_iam_member.jenkins-project", 
    "module.workload_identity.google_service_account_iam_member.main",
    "google_service_account.hubsa",
    "google_project_iam_member.hubaccess",
    "google_service_account_key.hubsa_credentials",
    "module.jenkins-gk.name"
    ]
  description = "Modules that are required to run before this module does"
  type        = list
}

variable "currentuser" {
  description = "Current-User"
  type        = string
}

variable "project_id" {
  description = "The project id to deploy Jenkins on GKE"
}

variable "tfstate_gcs_backend" {
  description = "Name of the GCS bucket to use as a backend for Terraform State"
  default     = "TFSTATE_GCS_BACKEND"
}

variable "region" {
  description = "The GCP region to deploy instances into"
  default     = "us-east4"
}

variable "zones" {
  description = "The GCP zone to deploy gke into"
  default     = ["us-east4-a"]
}

variable "jenkins_k8s_config" {
  description = "Name for the k8s secret required to configure k8s executers on Jenkins"
  default     = "jenkins-k8s-config"
}

variable "github_username" {
  description = "Github user/organization name where the terraform repo resides."
}

variable "github_token" {
  description = "Github token to access repo."
}

variable "github_repo" {
  description = "Github repo name."
  default     = "terraform-jenkins-pipeline"
}

variable "network" {
  description = "The name of the network to run the cluster"
  default     = "jenkins-vpc"
}

variable "subnetwork" {
  description = "The name of the subnet to run the cluster"
  default     = "jenkins-subnet"
}

variable "ip_range_pods" {
  description = "The secondary range name for the pods"
  default     = "pod-cidr-name"
}

variable "ip_range_services" {
  description = "The secondary range name for the services"
  default     = "service-cidr-name"
}

variable "ip_cidr_subnet_pods" {
  description = "The secondary ip range to use for pods"
  default     = "172.16.0.0/16"
}

variable "ip_cidr_subnet_services" {
  description = "The secondary ip range to use for pods"
  default     = "192.168.2.0/24"
}

variable "subnet_cidr" {
  default     = "10.2.0.0/16"
  description = "subnet cidr range"
}

variable clusname {
  default     = "jenkins-gke"
  description = "GKE cluster name"
}

 variable "service_account_name" {
   default = "jenkins-hub-sa"
 }

variable "acm_repo_location" {
  description = "The location of the git repo ACM will sync to"
}
variable "acm_branch" {
  description = "The git branch ACM will sync to"
}
variable "acm_dir" {
  description = "The directory in git ACM will sync to"
}
