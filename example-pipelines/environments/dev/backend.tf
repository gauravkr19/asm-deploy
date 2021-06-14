terraform {
  backend "gcs" {
    bucket = "-tfstate"
    prefix = "env/dev"
  }
}
