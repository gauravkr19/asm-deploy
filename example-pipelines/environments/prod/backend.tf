terraform {
  backend "gcs" {
    bucket = "playground-s-11-c1bb0be5-tfstate"
    prefix = "env/prod"
  }
}
