project_id               = ""
tfstate_gcs_backend      = "-tfstate"
region                   = "us-central1"
zones                    = ["us-central1-b"]
jenkins_k8s_config       = "jenkins-k8s-config"
ip_cidr_subnet_pods      = "172.16.0.0/16"
ip_cidr_subnet_services  = "192.168.2.0/24"
subnet_cidr              = "10.2.0.0/16"
currentuser              = "cloud_user_p_c8346591@linuxacademygclabs.com"
acm_repo_location   = "https://github.com/GoogleCloudPlatform/csp-config-management/"
acm_branch          = "1.0.0"
acm_dir             = "foo-corp"
