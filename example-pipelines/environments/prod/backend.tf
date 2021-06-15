terraform {
  backend "gcs" {
    bucket = "bcm-pcidss-devops-gaurav-tfstate"
    prefix = "env/prod"
  }
}
