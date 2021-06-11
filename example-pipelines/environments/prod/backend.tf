terraform {
  backend "gcs" {
    bucket = "playground-s-11-7eb2aa3f-tfstate"
    prefix = "env/prod"
  }
}
