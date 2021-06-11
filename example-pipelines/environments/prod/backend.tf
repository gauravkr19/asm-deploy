terraform {
  backend "gcs" {
    bucket = "playground-s-11-9804fbfe-tfstate"
    prefix = "env/prod"
  }
}
