terraform {
  backend "gcs" {
    bucket = "bcm-pcidss-devops-jenkins-tfstate"
    prefix = "env/dev"
  }
}
