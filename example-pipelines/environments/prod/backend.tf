terraform {
  backend "gcs" {
    bucket = "playground-s-11-20a7bec8-tfstate"
    prefix = "env/prod"
  }
}
