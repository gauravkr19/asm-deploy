terraform {
  backend "gcs" {
    bucket = "playground-s-11-9d871d0a-tfstate"
    prefix = "env/dev"
  }
}
