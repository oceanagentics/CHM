import {
  to = google_compute_subnetwork.default_us_east4
  id = "projects/chm-network/regions/us-east4/subnetworks/default"
}

resource "google_compute_subnetwork" "default_us_east4" {
  project                  = var.project_id
  name                     = "default"
  ip_cidr_range            = "10.150.0.0/20"
  region                   = var.region
  network                  = data.google_compute_network.default.id
  private_ip_google_access = true
  deletion_policy          = "ABANDON"
}
