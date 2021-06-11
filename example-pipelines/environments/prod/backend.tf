terraform {
  backend "gcs" {
    bucket = "playground-s-11-04e7a33c-tfstate"
    prefix = "env/prod"
  }
}
