terraform {
  backend "gcs" {
    bucket = "-tfstate"
    prefix = "env/prod"
  }
}
