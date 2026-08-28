locals {
  explorer_api_enabled = var.enable_explorer && var.enable_explorer_api
  explorer_api_image   = var.explorer_api_image != "" ? var.explorer_api_image : var.explorer_image
}

resource "google_service_account" "explorer" {
  count = var.enable_explorer ? 1 : 0

  project      = var.project_id
  account_id   = "explorer-sa"
  display_name = "Explorer Cloud Run service account"

  depends_on = [google_project_service.required]
}

resource "google_service_account" "explorer_api" {
  count = local.explorer_api_enabled ? 1 : 0

  project      = var.project_id
  account_id   = "explorer-api-sa"
  display_name = "Explorer private API Cloud Run service account"

  depends_on = [google_project_service.required]
}

resource "google_service_account" "explorer_migration" {
  count = var.enable_explorer ? 1 : 0

  project      = var.project_id
  account_id   = "explorer-migration-sa"
  display_name = "Explorer migration Cloud Run job service account"

  depends_on = [google_project_service.required]
}

resource "google_service_account" "explorer_build" {
  project      = var.project_id
  account_id   = "explorer-build-sa"
  display_name = "Explorer Cloud Build service account"

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret" "explorer_db_read_password" {
  count = var.enable_explorer ? 1 : 0

  project   = var.project_id
  secret_id = "explorer-db-read-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret" "explorer_db_write_password" {
  count = var.enable_explorer ? 1 : 0

  project   = var.project_id
  secret_id = "explorer-db-write-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret" "explorer_db_migration_password" {
  count = var.enable_explorer ? 1 : 0

  project   = var.project_id
  secret_id = "explorer-db-migration-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret_version" "explorer_db_read_password" {
  count = var.enable_explorer ? 1 : 0

  secret      = google_secret_manager_secret.explorer_db_read_password[0].id
  secret_data = random_password.explorer_read[0].result
}

resource "google_secret_manager_secret_version" "explorer_db_write_password" {
  count = var.enable_explorer ? 1 : 0

  secret      = google_secret_manager_secret.explorer_db_write_password[0].id
  secret_data = random_password.explorer_write[0].result
}

resource "google_secret_manager_secret_version" "explorer_db_migration_password" {
  count = var.enable_explorer ? 1 : 0

  secret      = google_secret_manager_secret.explorer_db_migration_password[0].id
  secret_data = random_password.explorer_migration[0].result
}

resource "google_project_iam_member" "explorer_cloud_sql_client" {
  count = var.enable_explorer ? 1 : 0

  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = google_service_account.explorer[0].member
}

resource "google_project_iam_member" "explorer_api_cloud_sql_client" {
  count = local.explorer_api_enabled ? 1 : 0

  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = google_service_account.explorer_api[0].member
}

resource "google_project_iam_member" "explorer_migration_cloud_sql_client" {
  count = var.enable_explorer ? 1 : 0

  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = google_service_account.explorer_migration[0].member
}

resource "google_secret_manager_secret_iam_member" "explorer_db_read_password_access" {
  count = var.enable_explorer ? 1 : 0

  project   = var.project_id
  secret_id = google_secret_manager_secret.explorer_db_read_password[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.explorer[0].member
}

resource "google_secret_manager_secret_iam_member" "explorer_db_write_password_access" {
  count = local.explorer_api_enabled ? 1 : 0

  project   = var.project_id
  secret_id = google_secret_manager_secret.explorer_db_write_password[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.explorer_api[0].member
}

resource "google_secret_manager_secret_iam_member" "explorer_db_migration_password_access" {
  count = var.enable_explorer ? 1 : 0

  project   = var.project_id
  secret_id = google_secret_manager_secret.explorer_db_migration_password[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.explorer_migration[0].member
}

resource "google_artifact_registry_repository_iam_member" "explorer_cloud_build_artifact_writer" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.chm_apps.repository_id
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.explorer_build.member
}

resource "google_storage_bucket_iam_member" "explorer_cloud_build_source_reader" {
  bucket = data.google_storage_bucket.cloud_build_source.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.explorer_build.member
}

resource "google_project_iam_member" "explorer_cloud_build_logs_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = google_service_account.explorer_build.member
}

resource "google_service_account_iam_member" "explorer_cloud_build_submitter" {
  service_account_id = google_service_account.explorer_build.name
  role               = "roles/iam.serviceAccountUser"
  member             = var.cloud_build_submitter_member
}

resource "google_cloud_run_v2_service" "explorer" {
  count = var.enable_explorer ? 1 : 0

  project             = var.project_id
  name                = "explorer"
  location            = var.region
  deletion_protection = true
  ingress             = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = google_service_account.explorer[0].email

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"

      network_interfaces {
        network    = "default"
        subnetwork = "default"
      }
    }

    scaling {
      min_instance_count = var.explorer_min_instance_count
      max_instance_count = var.explorer_max_instance_count
    }

    volumes {
      name = "cloudsql"

      cloud_sql_instance {
        instances = [google_sql_database_instance.chm[0].connection_name]
      }
    }

    containers {
      image = var.explorer_image

      ports {
        container_port = 8080
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }

      env {
        name  = "APP_BASE_PATH"
        value = "/explorer"
      }

      env {
        name  = "RYU_DATA_BACKEND"
        value = "postgres"
      }

      env {
        name  = "RYU_MODE"
        value = "public"
      }

      dynamic "env" {
        for_each = var.explorer_iap_backend_service_id != "" ? [1] : []

        content {
          name  = "IAP_JWT_AUDIENCE"
          value = "/projects/${var.project_number}/global/backendServices/${var.explorer_iap_backend_service_id}"
        }
      }

      env {
        name  = "PGHOST"
        value = "/cloudsql/${google_sql_database_instance.chm[0].connection_name}"
      }

      env {
        name  = "PGDATABASE"
        value = google_sql_database.explorer[0].name
      }

      env {
        name  = "PGUSER"
        value = google_sql_user.explorer_read[0].name
      }

      env {
        name = "PGPASSWORD"

        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.explorer_db_read_password[0].secret_id
            version = "latest"
          }
        }
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      startup_probe {
        initial_delay_seconds = 5
        period_seconds        = 5
        timeout_seconds       = 2
        failure_threshold     = 12

        http_get {
          path = "/healthz"
          port = 8080
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.explorer_image != ""
      error_message = "explorer_image must be set when enable_explorer is true."
    }
  }

  depends_on = [
    google_artifact_registry_repository.chm_apps,
    google_project_iam_member.explorer_cloud_sql_client,
    google_secret_manager_secret_version.explorer_db_read_password,
    google_sql_database.explorer,
    google_sql_user.explorer_read,
  ]
}

resource "google_cloud_run_v2_service" "explorer_api" {
  count = local.explorer_api_enabled ? 1 : 0

  project             = var.project_id
  name                = "explorer-api"
  location            = var.region
  deletion_protection = true
  ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    service_account = google_service_account.explorer_api[0].email

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"

      network_interfaces {
        network    = "default"
        subnetwork = "default"
      }
    }

    scaling {
      min_instance_count = var.explorer_api_min_instance_count
      max_instance_count = var.explorer_api_max_instance_count
    }

    volumes {
      name = "cloudsql"

      cloud_sql_instance {
        instances = [google_sql_database_instance.chm[0].connection_name]
      }
    }

    containers {
      image = local.explorer_api_image

      ports {
        container_port = 8080
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }

      env {
        name  = "APP_BASE_PATH"
        value = "/explorer"
      }

      env {
        name  = "RYU_DATA_BACKEND"
        value = "postgres"
      }

      env {
        name  = "RYU_MODE"
        value = "api"
      }

      env {
        name  = "RYU_TRUSTED_CALLER_SERVICE_ACCOUNTS"
        value = google_service_account.chm.email
      }

      env {
        name  = "PGHOST"
        value = "/cloudsql/${google_sql_database_instance.chm[0].connection_name}"
      }

      env {
        name  = "PGDATABASE"
        value = google_sql_database.explorer[0].name
      }

      env {
        name  = "PGUSER"
        value = google_sql_user.explorer_write[0].name
      }

      env {
        name = "PGPASSWORD"

        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.explorer_db_write_password[0].secret_id
            version = "latest"
          }
        }
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      startup_probe {
        initial_delay_seconds = 5
        period_seconds        = 5
        timeout_seconds       = 2
        failure_threshold     = 12

        http_get {
          path = "/healthz"
          port = 8080
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = local.explorer_api_image != ""
      error_message = "explorer_image or explorer_api_image must be set when enable_explorer_api is true."
    }
  }

  depends_on = [
    google_artifact_registry_repository.chm_apps,
    google_project_iam_member.explorer_api_cloud_sql_client,
    google_secret_manager_secret_version.explorer_db_write_password,
    google_sql_database.explorer,
    google_sql_user.explorer_write,
  ]
}

resource "google_compute_region_network_endpoint_group" "explorer" {
  count = var.enable_explorer ? 1 : 0

  project               = var.project_id
  name                  = "explorer-web-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = google_cloud_run_v2_service.explorer[0].name
  }
}

resource "google_compute_backend_service" "explorer" {
  count = var.enable_explorer ? 1 : 0

  project               = var.project_id
  name                  = "explorer-web-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"
  enable_cdn            = false
  timeout_sec           = 30

  backend {
    group = google_compute_region_network_endpoint_group.explorer[0].id
  }

  iap {
    enabled = true
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_cloud_run_v2_service_iam_member" "explorer_iap_invoker" {
  count = var.enable_explorer ? 1 : 0

  project  = var.project_id
  location = google_cloud_run_v2_service.explorer[0].location
  name     = google_cloud_run_v2_service.explorer[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_project_service_identity.iap.email}"
}

resource "google_iap_web_backend_service_iam_member" "explorer_domain" {
  count = var.enable_explorer ? 1 : 0

  project             = var.project_id
  web_backend_service = google_compute_backend_service.explorer[0].name
  role                = "roles/iap.httpsResourceAccessor"
  member              = var.iap_member
}

resource "google_cloud_run_v2_service_iam_member" "explorer_api_chm_invoker" {
  count = local.explorer_api_enabled ? 1 : 0

  project  = var.project_id
  location = google_cloud_run_v2_service.explorer_api[0].location
  name     = google_cloud_run_v2_service.explorer_api[0].name
  role     = "roles/run.invoker"
  member   = google_service_account.chm.member
}
