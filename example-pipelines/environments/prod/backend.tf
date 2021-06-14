terraform {
  backend "gcs" {
    bucket = "playground-s-11-d4f6d321-tfstate"
    prefix = "env/prod"
  }
}
