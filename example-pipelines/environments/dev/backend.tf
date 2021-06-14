terraform {
  backend "gcs" {
    bucket = "playground-s-11-c0c92cac-tfstate"
    prefix = "env/dev"
  }
}
