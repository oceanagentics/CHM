terraform {
  backend "gcs" {
    bucket = "chm-network-tfstate-288836337031"
    prefix = "chm"
  }
}
