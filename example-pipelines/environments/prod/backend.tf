terraform {
  backend "gcs" {
    bucket = "playground-s-11-07caf841-tfstate"
    prefix = "env/prod"
  }
}
