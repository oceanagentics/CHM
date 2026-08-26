resource "google_compute_global_address" "chm" {
  project = var.project_id
  name    = "chm-lb-ip"

  depends_on = [google_project_service.required]
}

resource "google_compute_managed_ssl_certificate" "chm" {
  project = var.project_id
  name    = "chm-oceanagentics-org-cert"

  managed {
    domains = [var.domain]
  }

  depends_on = [google_project_service.required]
}

resource "google_compute_region_network_endpoint_group" "chm" {
  project               = var.project_id
  name                  = "chm-web-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = google_cloud_run_v2_service.chm.name
  }
}

resource "google_compute_backend_service" "chm" {
  project               = var.project_id
  name                  = "chm-web-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"
  enable_cdn            = false
  timeout_sec           = 30

  backend {
    group = google_compute_region_network_endpoint_group.chm.id
  }

  iap {
    enabled = true
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "chm" {
  project = var.project_id
  name    = "chm-url-map"

  default_service = google_compute_backend_service.chm.id

  host_rule {
    hosts        = [var.domain]
    path_matcher = "chm"
  }

  path_matcher {
    name            = "chm"
    default_service = google_compute_backend_service.chm.id

    path_rule {
      paths   = ["/", "/login"]
      service = google_compute_backend_service.chm.id
    }
  }

  test {
    host    = var.domain
    path    = "/"
    service = google_compute_backend_service.chm.id
  }

  test {
    host    = var.domain
    path    = "/login"
    service = google_compute_backend_service.chm.id
  }
}

resource "google_compute_target_https_proxy" "chm" {
  project          = var.project_id
  name             = "chm-https-proxy"
  url_map          = google_compute_url_map.chm.id
  ssl_certificates = [google_compute_managed_ssl_certificate.chm.id]
}

resource "google_compute_global_forwarding_rule" "chm_https" {
  project               = var.project_id
  name                  = "chm-https-forwarding-rule"
  ip_address            = google_compute_global_address.chm.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.chm.id
}
