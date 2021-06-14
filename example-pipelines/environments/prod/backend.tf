terraform {
  backend "gcs" {
    bucket = "playground-s-11-766c0448-tfstate"
    prefix = "env/prod"
  }
}
