terraform {
  backend "gcs" {
    bucket = "playground-s-11-2220a4b5-tfstate"
    prefix = "env/prod"
  }
}
