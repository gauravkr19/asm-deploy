terraform {
  backend "gcs" {
    bucket = "playground-s-11-663a69d8-tfstate"
    prefix = "env/prod"
  }
}
