output "example_vpc_name" {
  value = module.gcp-network.network_name
}

output "example_vm_name" {
  value = google_compute_instance.vm_0001.name
}
