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

resource "google_compute_managed_ssl_certificate" "chm_alternate" {
  project = var.project_id
  name    = "chm-oceanagentics-com-cert"

  managed {
    domains = [var.alternate_domain]
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
    hosts        = [var.domain, var.alternate_domain]
    path_matcher = "chm"
  }

  path_matcher {
    name            = "chm"
    default_service = google_compute_backend_service.chm.id

    path_rule {
      paths   = ["/", "/login"]
      service = google_compute_backend_service.chm.id
    }

    path_rule {
      paths   = ["/api/explorer", "/api/explorer/*"]
      service = google_compute_backend_service.chm.id
    }

    dynamic "path_rule" {
      for_each = var.enable_explorer ? [1] : []

      content {
        paths   = ["/explorer/admin", "/explorer/admin/*"]
        service = google_compute_backend_service.explorer_admin[0].id
      }
    }

    dynamic "path_rule" {
      for_each = var.enable_explorer ? [1] : []

      content {
        paths   = ["/explorer", "/explorer/*"]
        service = google_compute_backend_service.explorer[0].id
      }
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

  test {
    host    = var.alternate_domain
    path    = "/"
    service = google_compute_backend_service.chm.id
  }

  test {
    host    = var.alternate_domain
    path    = "/login"
    service = google_compute_backend_service.chm.id
  }

  dynamic "test" {
    for_each = var.enable_explorer ? [1] : []

    content {
      host    = var.domain
      path    = "/explorer/admin"
      service = google_compute_backend_service.explorer_admin[0].id
    }
  }

  dynamic "test" {
    for_each = var.enable_explorer ? [1] : []

    content {
      host    = var.domain
      path    = "/explorer/admin/"
      service = google_compute_backend_service.explorer_admin[0].id
    }
  }

  test {
    host    = var.domain
    path    = "/api/explorer/nodes/fishbase/review"
    service = google_compute_backend_service.chm.id
  }

  dynamic "test" {
    for_each = var.enable_explorer ? [1] : []

    content {
      host    = var.domain
      path    = "/explorer"
      service = google_compute_backend_service.explorer[0].id
    }
  }

  dynamic "test" {
    for_each = var.enable_explorer ? [1] : []

    content {
      host    = var.domain
      path    = "/explorer/"
      service = google_compute_backend_service.explorer[0].id
    }
  }
}

resource "google_compute_target_https_proxy" "chm" {
  project = var.project_id
  name    = "chm-https-proxy"
  url_map = google_compute_url_map.chm.id
  ssl_certificates = [
    google_compute_managed_ssl_certificate.chm.id,
    google_compute_managed_ssl_certificate.chm_alternate.id,
  ]
}

resource "google_compute_url_map" "chm_http_redirect" {
  project = var.project_id
  name    = "chm-http-redirect-url-map"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "chm_http_redirect" {
  project = var.project_id
  name    = "chm-http-redirect-proxy"
  url_map = google_compute_url_map.chm_http_redirect.id
}

resource "google_compute_global_forwarding_rule" "chm_https" {
  project               = var.project_id
  name                  = "chm-https-forwarding-rule"
  ip_address            = google_compute_global_address.chm.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.chm.id
}

resource "google_compute_global_forwarding_rule" "chm_http_redirect" {
  project               = var.project_id
  name                  = "chm-http-redirect-forwarding-rule"
  ip_address            = google_compute_global_address.chm.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.chm_http_redirect.id
}
