project_id               = "bcm-pcidss-devops-jenkins"
tfstate_gcs_backend      = "bcm-pcidss-devops-jenkins-tfstate"
region                   = "us-central1"
zones                    = ["us-central1-b"]
jenkins_k8s_config       = "jenkins-k8s-config"
ip_cidr_subnet_pods      = "172.16.0.0/16"
ip_cidr_subnet_services  = "192.168.2.0/24"
subnet_cidr              = "10.2.0.0/16"
currentuser              = "cloud_user_p_702cc552@linuxacademygclabs.com"
