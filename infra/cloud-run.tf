resource "google_cloud_run_v2_service" "chm" {
  project             = var.project_id
  name                = "chm"
  location            = var.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = google_service_account.chm.email

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }

    containers {
      image = var.chm_image

      ports {
        container_port = 8080
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      startup_probe {
        http_get {
          path = "/healthz"
          port = 8080
        }
      }
    }
  }

  depends_on = [
    google_artifact_registry_repository.chm_apps,
    google_project_service.required,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "iap_invoker" {
  project  = var.project_id
  location = google_cloud_run_v2_service.chm.location
  name     = google_cloud_run_v2_service.chm.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_project_service_identity.iap.email}"
}
