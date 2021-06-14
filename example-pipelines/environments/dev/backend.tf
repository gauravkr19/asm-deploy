terraform {
  backend "gcs" {
    bucket = "playground-s-11-045f8aad-tfstate"
    prefix = "env/dev"
  }
}
