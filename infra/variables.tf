variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
  default     = "chm-network"
}

variable "project_number" {
  description = "Google Cloud project number, used for the IAP service agent."
  type        = string
  default     = "288836337031"
}

variable "region" {
  description = "Primary Cloud Run region."
  type        = string
  default     = "us-east4"
}

variable "domain" {
  description = "Public CHM domain."
  type        = string
  default     = "chm.oceanagentics.org"
}

variable "alternate_domain" {
  description = "Additional CHM domain served by the same load balancer."
  type        = string
  default     = "chm.oceanagentics.com"
}

variable "chm_image" {
  description = "Container image for the CHM Cloud Run service."
  type        = string
}

variable "iap_member" {
  description = "Initial IAP access principal for CHM."
  type        = string
  default     = "domain:oceanagentics.com"
}

variable "iap_backend_service_id" {
  description = "Numeric CHM backend service ID used in the IAP JWT audience."
  type        = string
  default     = "1981640158971360804"
}

variable "cloud_build_submitter_member" {
  description = "Operator allowed to submit CHM builds as the dedicated Cloud Build service account."
  type        = string
  default     = "user:danny@oceanagentics.com"
}

variable "alert_email" {
  description = "Email notification channel for CHM security and availability alerts."
  type        = string
  default     = "danny@oceanagentics.com"
}

variable "chm_admin_hint_emails" {
  description = "Authenticated CHM user emails that receive the public Explorer admin redirect hint cookie."
  type        = list(string)
  default     = ["danny@oceanagentics.com"]
}

variable "enable_explorer" {
  description = "Create Explorer Cloud Run, Cloud SQL, and /explorer load-balancer resources."
  type        = bool
  default     = false
}

variable "enable_explorer_api" {
  description = "Create the private Explorer browser-review API service when Explorer is enabled."
  type        = bool
  default     = true
}

variable "explorer_image" {
  description = "Container image for the public read-only Explorer Cloud Run service. Required when enable_explorer is true."
  type        = string
  default     = ""
}

variable "explorer_admin_image" {
  description = "Container image for the IAP-protected Explorer admin Cloud Run service. Required when enable_explorer is true."
  type        = string
  default     = ""
}

variable "explorer_api_image" {
  description = "Container image for the private Explorer API service. Defaults to explorer_image when empty."
  type        = string
  default     = ""
}

variable "explorer_iap_backend_service_id" {
  description = "Deprecated: use explorer_admin_iap_backend_service_id for Explorer app-level IAP JWT validation."
  type        = string
  default     = "4582439918390522076"
}

variable "explorer_admin_iap_backend_service_id" {
  description = "Numeric Explorer admin backend service ID used for app-level IAP JWT validation. Leave empty only during the first admin bootstrap before the backend exists."
  type        = string
  default     = ""
}

variable "cloud_sql_tier" {
  description = "Cloud SQL machine tier for the shared CHM PostgreSQL instance."
  type        = string
  default     = "db-f1-micro"
}

variable "cloud_sql_disk_size_gb" {
  description = "Initial disk size for the shared CHM PostgreSQL instance."
  type        = number
  default     = 10
}

variable "cloud_sql_backup_start_time" {
  description = "UTC time window start for Cloud SQL backups."
  type        = string
  default     = "09:00"
}

variable "explorer_min_instance_count" {
  description = "Minimum instances for the browser-facing Explorer service."
  type        = number
  default     = 0
}

variable "explorer_max_instance_count" {
  description = "Maximum instances for the browser-facing Explorer service."
  type        = number
  default     = 3
}

variable "explorer_admin_min_instance_count" {
  description = "Minimum instances for the IAP-protected Explorer admin service."
  type        = number
  default     = 0
}

variable "explorer_admin_max_instance_count" {
  description = "Maximum instances for the IAP-protected Explorer admin service."
  type        = number
  default     = 2
}

variable "explorer_api_min_instance_count" {
  description = "Minimum instances for the private Explorer API service."
  type        = number
  default     = 0
}

variable "explorer_api_max_instance_count" {
  description = "Maximum instances for the private Explorer API service."
  type        = number
  default     = 2
}
