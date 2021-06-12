/*****************************************
  Locals
 *****************************************/
locals {
  vpc_network_name = "example-vpc-${var.environment}"
  vm_name = "example-vm-${var.environment}-retail"
}

/*****************************************
  Google Provider Configuration
 *****************************************/
provider "google" {
  #version = "~> 2.18.0"
}

/*****************************************
  Create a VPC Network 
 *****************************************/
module "gcp-network" {
  source       = "terraform-google-modules/network/google"
  #version      = "~> 1.4.0"
  project_id   = var.project_id
  network_name = local.vpc_network_name

  subnets = [
    {
      subnet_name   = "${local.vpc_network_name}-${var.subnet1_region}"
      subnet_ip     = var.subnet1_cidr
      subnet_region = var.subnet1_region
    },
  ]
}

/*****************************************
  Create a GCE VM Instance
 *****************************************/
# resource "google_compute_instance" "vm_0001" {
#   project      = var.project_id
#   zone         = var.subnet1_zone
#   name         = local.vm_name
#   machine_type = "f1-micro"
#   tags         = ["bar"]
  
#   scheduling {
#     preemptible = true
#     automatic_restart = false
#   }

#   network_interface {
#     network    = module.gcp-network.network_name
#     subnetwork = module.gcp-network.subnets_self_links[0]
#   }
  
#   boot_disk {
#     initialize_params {
#       image = "debian-cloud/debian-9"
#     }
#   }
# }
