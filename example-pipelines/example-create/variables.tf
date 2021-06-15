variable "project_id" {
  type        = string
  description = "Project ID of GCP project to be used"
  default     = ""
}

variable "environment" {
  type        = string
  description = "Name of the environment (dev or prod)"
  default     = "dev"
}

variable "subnet1_region" {
  type        = string
  description = "GCP Region where first subnet will be created"
  default     = "us-central1"
}

variable "subnet1_zone" {
  type        = string
  description = "GCP Zone within Subnet1 Region where GCE instance will be created"
  default     = "us-central1-a"
}

variable "subnet1_cidr" {
  type        = string
  description = "VPC Network CIDR to be assigned to the VPC being created"
  default     = "10.0.0.0/17"
}
