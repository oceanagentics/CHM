# CHM Deploy Notes

## Current Scope

The current deployment runs the CHM portal and Explorer slice on Cloud Run
behind the IAP-protected HTTPS load balancer.

Terraform manages the Artifact Registry repository, Cloud Run services, load balancer, certificates, URL map, IAP access, Cloud SQL, app service accounts, database secrets, and monitoring. DNS remains manual in Dynadot.

The Explorer slice is gated by `enable_explorer`. The live CHM project currently runs that slice; keep it disabled only for fresh/bootstrap applies until an Explorer image exists and Cloud SQL cost is approved.

## Current Deployment

Initial apply on 2026-08-26; warm-instance update on 2026-08-27; Explorer,
alerting, Cloud SQL deletion-protection, and Explorer IAP JWT validation updates
on 2026-08-28; review UI/API and CHM-to-internal-API VPC fix on 2026-08-31:

- Project: `chm-network`
- Region: `us-east4`
- Cloud Run service: `chm`
- Image: `us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:29ea43ef4d384d5d1252f241202e6938829654d77e1682d1c756fbb296abdff5`
- CHM Cloud Run revision: `chm-00008-vx8`
- Scaling: 1 minimum instance, 3 maximum instances
- Cloud Run deletion protection: enabled
- CHM Direct VPC egress: default `us-east4` subnet, `all-traffic`
- Default `us-east4` subnet: Terraform-imported with Private Google Access
  enabled and `deletion_policy = "ABANDON"`
- Cloud SQL deletion protection: Terraform and Cloud SQL platform flag enabled
- Cloud Build service account: `chm-build-sa@chm-network.iam.gserviceaccount.com`
- Explorer Cloud Run services: `explorer` and private `explorer-api`
- Explorer source commit: `6a03086`
- Explorer Cloud Run revision: `explorer-00009-75l`
- Explorer API Cloud Run revision: `explorer-api-00008-mhc`
- Explorer image: `us-east4-docker.pkg.dev/chm-network/chm-apps/explorer@sha256:e2b744ed43b60f99e6740e5e2a156c8bffc39192a75ff7a2af6dac17e471f29e`
- Explorer Cloud Build service account: `explorer-build-sa@chm-network.iam.gserviceaccount.com`
- Cloud SQL instance: `chm`, database `explorer`
- CHM IAP JWT audience: `/projects/288836337031/global/backendServices/1981640158971360804`
- Explorer IAP JWT audience: `/projects/288836337031/global/backendServices/4582439918390522076`
- Load balancer IP: `34.110.145.254`
- Managed certificates: `chm-oceanagentics-org-cert`, `chm-oceanagentics-com-cert`
- Hostnames: `chm.oceanagentics.org`, `chm.oceanagentics.com`
- HTTP: port 80 redirects to the matching HTTPS URL
- Alerts: confirmed Cloud Monitoring email channel `danny@oceanagentics.com`
  with policies for IAP failures, Cloud Run 5xx spikes, IAM policy changes, and
  service-account key creation
- Unmanaged Explorer Cloud Run setup/check jobs: deleted after launch setup and
  verification completed

Terraform reported no drift on 2026-08-31 with the currently deployed image
digests:

```sh
cd /Users/danvallentyne/dev/CHM/infra
terraform plan \
  -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:29ea43ef4d384d5d1252f241202e6938829654d77e1682d1c756fbb296abdff5 \
  -var enable_explorer=true \
  -var explorer_image=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer@sha256:e2b744ed43b60f99e6740e5e2a156c8bffc39192a75ff7a2af6dac17e471f29e \
  -var explorer_iap_backend_service_id=4582439918390522076
```

Public DNS now points both CHM hostnames at the load balancer. Unauthenticated HTTPS requests should go to the Google IAP login flow, and signed-in `@oceanagentics.com` users should reach the CHM app.

## One-Time Bootstrap

Terraform state is stored in the GCS bucket `chm-network-tfstate-288836337031` with prefix `chm`.

The CHM image must exist before the full Terraform apply can create the Cloud Run service. The Artifact Registry repository must exist before the image can be pushed.

Bootstrap Terraform state and the image repository first:

```sh
gcloud storage buckets create gs://chm-network-tfstate-288836337031 --project chm-network --location us-east4 --uniform-bucket-level-access
gcloud storage buckets update gs://chm-network-tfstate-288836337031 --versioning
```

Then initialize Terraform:

```sh
cd /Users/danvallentyne/dev/CHM/infra
terraform init
```

Then bootstrap the image repository and build service account:

```sh
cd /Users/danvallentyne/dev/CHM/infra
terraform apply \
  -target=google_project_service.required \
  -target=google_artifact_registry_repository.chm_apps \
  -target=google_service_account.chm_build \
  -target=google_storage_bucket_iam_member.cloud_build_source_reader \
  -target=google_artifact_registry_repository_iam_member.cloud_build_artifact_writer \
  -target=google_project_iam_member.cloud_build_logs_writer \
  -target=google_service_account_iam_member.cloud_build_submitter
```

Then build and push the app image. The build config uses the dedicated CHM Cloud Build service account and stores build logs in Cloud Logging:

```sh
cd /Users/danvallentyne/dev/CHM
gcloud builds submit --region us-east4 --config cloudbuild.yaml .
```

Then review and apply the full plan:

```sh
cd /Users/danvallentyne/dev/CHM/infra
terraform plan -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<image-digest>
terraform apply -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<image-digest>
```

After apply, use the `load_balancer_ip` output to create or update this Dynadot DNS record:

```text
chm.oceanagentics.org A 34.110.145.254
chm.oceanagentics.com A 34.110.145.254
```

After DNS propagates, check certificate status:

```sh
gcloud compute ssl-certificates describe chm-oceanagentics-org-cert --global --project chm-network --format='get(managed.status)'
gcloud compute ssl-certificates describe chm-oceanagentics-com-cert --global --project chm-network --format='get(managed.status)'
```

When the certificate is active, unauthenticated requests to `/` and `/login` should go to the Google IAP login flow, and signed-in `@oceanagentics.com` users should reach the CHM app.

## Explorer Deployment Slice

First apply CHM Terraform without enabling Explorer so the non-billable Explorer build identity exists:

```sh
cd /Users/danvallentyne/dev/CHM/infra
terraform plan -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<chm-image-digest>
terraform apply -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<chm-image-digest>
```

Then build the Explorer image from the Ryu repo:

```sh
cd /Users/danvallentyne/dev/oceanagentics/ryu
gcloud builds submit \
  --region us-east4 \
  --config cloudbuild.yaml \
  --substitutions _IMAGE=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer:$(git rev-parse --short HEAD) \
  .
```

Then apply the gated Explorer infrastructure:

```sh
cd /Users/danvallentyne/dev/CHM/infra
terraform plan \
  -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<chm-image-digest> \
  -var enable_explorer=true \
  -var explorer_image=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer@sha256:<explorer-image-digest> \
  -var explorer_iap_backend_service_id=4582439918390522076
terraform apply \
  -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<chm-image-digest> \
  -var enable_explorer=true \
  -var explorer_image=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer@sha256:<explorer-image-digest> \
  -var explorer_iap_backend_service_id=4582439918390522076
```

The initial Explorer database setup and seed were completed during launch. The
unmanaged Cloud Run setup/check jobs used for that work have been deleted. Keep
the production Postgres shape in the Explorer repo SQL and docs; design the next
database-change runner only when a real schema change is needed.

The current review UI/API update is deployed:

- Explorer image: includes the details-panel review section and private
  `PATCH /explorer/api/nodes/:id/review` mutation.
- CHM image: proxies only `PATCH /api/explorer/nodes/:id/review` to the private
  Explorer API.

The CHM service needs Direct VPC egress with `all-traffic`, and the default
`us-east4` subnet needs Private Google Access enabled, so CHM service-to-service
requests to the internal-only `explorer-api` are treated as internal traffic.

Expected checks after routing is enabled:

```sh
curl -I https://chm.oceanagentics.org/explorer
curl -I https://chm.oceanagentics.com/explorer
```

Unauthenticated requests should be redirected by IAP before reaching Explorer.
Authenticated browser loading of real Explorer graph data has been confirmed.
The private backend review path was verified on 2026-08-31 by a temporary Cloud
Run probe running as `chm-sa`: it updated `fishbase` as
`danny@oceanagentics.com`, rejected unsupported fields, rejected missing user
context, rejected the wrong caller header, and confirmed the general node write
route is absent. The remaining browser-only check is selecting a node in a
signed-in CHM/IAP session, editing review state or reviewer note, and confirming
the UI shows the persisted `reviewState`, `reviewerNote`, `reviewer`, and
`lastReviewed` fields.
