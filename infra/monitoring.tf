resource "google_monitoring_notification_channel" "security_email" {
  project      = var.project_id
  display_name = "CHM security alerts"
  type         = "email"
  enabled      = true

  labels = {
    email_address = var.alert_email
  }

  depends_on = [google_project_service.required]
}

resource "google_monitoring_alert_policy" "iap_auth_failures" {
  project      = var.project_id
  display_name = "CHM IAP authentication failures"
  combiner     = "OR"
  enabled      = true
  severity     = "WARNING"

  notification_channels = [google_monitoring_notification_channel.security_email.name]

  conditions {
    display_name = "IAP returned 401 or 403"

    condition_matched_log {
      filter = <<-EOT
        resource.type="http_load_balancer"
        resource.labels.url_map_name="chm-url-map"
        jsonPayload.statusDetails="handled_by_identity_aware_proxy"
        (httpRequest.status=401 OR httpRequest.status=403)
      EOT
    }
  }

  alert_strategy {
    auto_close = "86400s"

    notification_rate_limit {
      period = "3600s"
    }
  }

  documentation {
    mime_type = "text/markdown"
    content   = "IAP returned an authentication or authorization failure for CHM. Review load balancer request logs and IAP access policy."
  }
}

resource "google_monitoring_alert_policy" "cloud_run_5xx" {
  project      = var.project_id
  display_name = "CHM Cloud Run 5xx responses"
  combiner     = "OR"
  enabled      = true
  severity     = "ERROR"

  notification_channels = [google_monitoring_notification_channel.security_email.name]

  conditions {
    display_name = "Cloud Run 5xx responses exceed baseline"

    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND metric.type = \"run.googleapis.com/request_count\" AND metric.label.response_code_class = \"5xx\""
      comparison      = "COMPARISON_GT"
      duration        = "300s"
      threshold_value = 5

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.service_name"]
      }

      trigger {
        count = 1
      }
    }
  }

  documentation {
    mime_type = "text/markdown"
    content   = "Cloud Run returned more than five 5xx responses in five minutes. Check CHM and Explorer Cloud Run logs."
  }
}

resource "google_monitoring_alert_policy" "iam_policy_changes" {
  project      = var.project_id
  display_name = "CHM IAM policy changes"
  combiner     = "OR"
  enabled      = true
  severity     = "WARNING"

  notification_channels = [google_monitoring_notification_channel.security_email.name]

  conditions {
    display_name = "IAM policy changed"

    condition_matched_log {
      filter = <<-EOT
        logName="projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity"
        protoPayload.methodName:"SetIamPolicy"
      EOT
    }
  }

  alert_strategy {
    auto_close = "86400s"

    notification_rate_limit {
      period = "3600s"
    }
  }

  documentation {
    mime_type = "text/markdown"
    content   = "A Google Cloud IAM policy changed in the CHM project. Confirm the change was intentional and matches Terraform."
  }
}

resource "google_monitoring_alert_policy" "service_account_key_creation" {
  project      = var.project_id
  display_name = "CHM service account key creation"
  combiner     = "OR"
  enabled      = true
  severity     = "ERROR"

  notification_channels = [google_monitoring_notification_channel.security_email.name]

  conditions {
    display_name = "Service account key created or uploaded"

    condition_matched_log {
      filter = <<-EOT
        logName="projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity"
        protoPayload.serviceName="iam.googleapis.com"
        (protoPayload.methodName="google.iam.admin.v1.CreateServiceAccountKey" OR protoPayload.methodName="google.iam.admin.v1.UploadServiceAccountKey")
      EOT
    }
  }

  alert_strategy {
    auto_close = "86400s"

    notification_rate_limit {
      period = "3600s"
    }
  }

  documentation {
    mime_type = "text/markdown"
    content   = "A long-lived service account key was created or uploaded. CHM should use service accounts without downloaded JSON keys."
  }
}
