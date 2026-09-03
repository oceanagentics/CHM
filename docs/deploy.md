# CHM Deploy Notes

## Current Scope

The current deployment runs the CHM portal and Explorer slice on Cloud Run
behind the shared HTTPS load balancer. CHM and Explorer admin are IAP-protected;
public Explorer at `/explorer` is read-only and unauthenticated.

Terraform manages the Artifact Registry repository, Cloud Run services, load balancer, certificates, URL map, IAP access, Cloud SQL, app service accounts, database secrets, and monitoring. DNS remains manual in Dynadot.

The Explorer slice is gated by `enable_explorer`. The live CHM project currently runs that slice; keep it disabled only for fresh/bootstrap applies until Explorer public/admin images exist and Cloud SQL cost is approved.

## Current Deployment

Initial apply on 2026-08-26; warm-instance update on 2026-08-27; Explorer,
alerting, Cloud SQL deletion-protection, and Explorer IAP JWT validation updates
on 2026-08-28; review UI/API, CHM-to-internal-API VPC fix, and public/admin
Explorer path split on 2026-08-31; Explorer language migration rollout on
2026-09-01; direct bearer-token Explorer record API deployed on 2026-09-03;
API-only locale availability fix fast-deployed on 2026-09-03:

- Project: `chm-network`
- Region: `us-east4`
- Cloud Run service: `chm`
- Source commit: `07dd201`
- Image: `us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:a02418369050dfb52f5eba561df32628f6116ddc9c6f1a002d31ba7582c2c90e`
- CHM Cloud Run revision: `chm-00013-lvp`
- Scaling: 1 minimum instance, 3 maximum instances
- Cloud Run deletion protection: enabled
- CHM Direct VPC egress: default `us-east4` subnet, `all-traffic`
- Default `us-east4` subnet: Terraform-imported with Private Google Access
  enabled and `deletion_policy = "ABANDON"`
- Cloud SQL deletion protection: Terraform and Cloud SQL platform flag enabled
- Cloud Build service account: `chm-build-sa@chm-network.iam.gserviceaccount.com`
- Explorer Cloud Run services: public `explorer`, IAP-protected
  `explorer-admin`, and bearer-token `explorer-api`
- Explorer public/admin source commit: `d6b6992`
- Explorer API source commit: `7bb5257`
- Explorer public Cloud Run revision: `explorer-00018-7qw`
- Explorer admin Cloud Run revision: `explorer-admin-00008-qz9`
- Explorer API Cloud Run revision: `explorer-api-00017-2gh`
- Explorer public image: `us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-public@sha256:25e761049522571b0f0fb0521830c54418b8d12dca5ee91a9842d200bfe40ab5`
- Explorer admin image: `us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-admin@sha256:09c40f273c50c00d13b9a30ec1109a16da224b3729a054b22b0ec01b5a56d07f`
- Explorer API image: `us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-api@sha256:140b4da31e24142adb2a8043fce09cf1b04feb054ef43ac9f5e050e6acc1b86c`
- Explorer Cloud Build service account: `explorer-build-sa@chm-network.iam.gserviceaccount.com`
- Cloud SQL instance: `chm`, database `explorer`
- CHM IAP JWT audience: `/projects/288836337031/global/backendServices/1981640158971360804`
- CHM admin hint emails: `danny@oceanagentics.com`
- Admin redirect hint cookie: `chm_admin_hint`
- Explorer admin IAP JWT audience: `/projects/288836337031/global/backendServices/5570063593656309274`
- Load balancer IP: `34.110.145.254`
- Managed certificates: `chm-oceanagentics-org-cert`, `chm-oceanagentics-com-cert`
- Hostnames: `chm.oceanagentics.org`, `chm.oceanagentics.com`
- HTTP: port 80 redirects to the matching HTTPS URL
- Alerts: confirmed Cloud Monitoring email channel `danny@oceanagentics.com`
  with policies for IAP failures, Cloud Run 5xx spikes, IAM policy changes, and
  service-account key creation
- Explorer language migration backup: Cloud SQL backup `1788227781465`
- Explorer language migration execution: `explorer-lang-migration-226fc2c-klgm5`,
  backfilled `117` localization rows
- Unmanaged Explorer Cloud Run setup/check/migration jobs: deleted after launch
  setup and verification completed

Use these image digests for the next Terraform plan:

```sh
cd /Users/danvallentyne/dev/oceanagentics/CHM/infra
terraform plan \
  -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:a02418369050dfb52f5eba561df32628f6116ddc9c6f1a002d31ba7582c2c90e \
  -var 'chm_admin_hint_emails=["danny@oceanagentics.com"]' \
  -var enable_explorer=true \
  -var explorer_image=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-public@sha256:25e761049522571b0f0fb0521830c54418b8d12dca5ee91a9842d200bfe40ab5 \
  -var explorer_admin_image=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-admin@sha256:09c40f273c50c00d13b9a30ec1109a16da224b3729a054b22b0ec01b5a56d07f \
  -var explorer_api_image=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-api@sha256:140b4da31e24142adb2a8043fce09cf1b04feb054ef43ac9f5e050e6acc1b86c \
  -var explorer_admin_iap_backend_service_id=5570063593656309274
```

Public DNS now points both CHM hostnames at the load balancer. Unauthenticated
HTTPS requests to `/` and `/explorer/admin` should go to the Google IAP login
flow. Unauthenticated `/explorer` should serve the public read-only Explorer
view. Unauthenticated `/api/records` should return JSON
`401 missing_bearer_token`; invalid bearer tokens should return
`403 invalid_bearer_token`.

## Routine Fast App Deploy

Use this path for CHM code-only changes. It builds one cached image, pushes it
to Artifact Registry, and updates the existing Cloud Run service directly. Do
not run Terraform for image-only app deploys.

```sh
cd /Users/danvallentyne/dev/oceanagentics/CHM
SHA=$(git rev-parse --short HEAD)
IMAGE=us-east4-docker.pkg.dev/chm-network/chm-apps/chm:${SHA}
CACHE_IMAGE=us-east4-docker.pkg.dev/chm-network/chm-apps/chm:latest

gcloud builds submit \
  --region us-east4 \
  --config cloudbuild.yaml \
  --substitutions _IMAGE=${IMAGE},_CACHE_IMAGE=${CACHE_IMAGE} \
  .

gcloud run deploy chm \
  --project chm-network \
  --region us-east4 \
  --image ${IMAGE} \
  --quiet
```

Use Terraform only for infrastructure, IAM/IAP, Cloud SQL, secrets, routing,
service configuration, domain, or first-bootstrap changes. If a fast deploy
causes Terraform to report image drift later, do not roll the app image back
just to satisfy Terraform.

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
cd /Users/danvallentyne/dev/oceanagentics/CHM/infra
terraform init
```

Then bootstrap the image repository and build service account:

```sh
cd /Users/danvallentyne/dev/oceanagentics/CHM/infra
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
cd /Users/danvallentyne/dev/oceanagentics/CHM
gcloud builds submit --region us-east4 --config cloudbuild.yaml .
```

Then review and apply the full plan:

```sh
cd /Users/danvallentyne/dev/oceanagentics/CHM/infra
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
cd /Users/danvallentyne/dev/oceanagentics/CHM/infra
terraform plan -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<chm-image-digest>
terraform apply -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<chm-image-digest>
```

Then build the public and admin Explorer images from the Ryu repo:

```sh
cd /Users/danvallentyne/dev/oceanagentics/ryu
gcloud builds submit \
  --region us-east4 \
  --config cloudbuild.yaml \
  --substitutions _IMAGE=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-public:$(git rev-parse --short HEAD),_CACHE_IMAGE=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-public:latest,_APP_BASE_PATH=/explorer,_VITE_APP_MODE=public,_VITE_CAN_REVIEW_NODES=false \
  .
gcloud builds submit \
  --region us-east4 \
  --config cloudbuild.yaml \
  --substitutions _IMAGE=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-admin:$(git rev-parse --short HEAD),_CACHE_IMAGE=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-admin:latest,_APP_BASE_PATH=/explorer/admin,_VITE_APP_MODE=author,_VITE_CAN_REVIEW_NODES=true \
  .
```

Then apply the gated Explorer infrastructure:

```sh
cd /Users/danvallentyne/dev/oceanagentics/CHM/infra
terraform plan \
  -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<chm-image-digest> \
  -var enable_explorer=true \
  -var explorer_image=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-public@sha256:<explorer-public-image-digest> \
  -var explorer_admin_image=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-admin@sha256:<explorer-admin-image-digest> \
  -var explorer_admin_iap_backend_service_id=<explorer-admin-web-backend-id>
terraform apply \
  -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<chm-image-digest> \
  -var enable_explorer=true \
  -var explorer_image=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-public@sha256:<explorer-public-image-digest> \
  -var explorer_admin_image=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-admin@sha256:<explorer-admin-image-digest> \
  -var explorer_admin_iap_backend_service_id=<explorer-admin-web-backend-id>
```

If `explorer-admin-web-backend` does not exist yet, run the first apply with
`explorer_admin_iap_backend_service_id=` to create it, read the numeric backend
ID, then immediately apply again with that ID so `explorer-admin` validates the
signed IAP JWT assertion in the app.

The initial Explorer database setup and seed were completed during launch. The
unmanaged Cloud Run setup/check jobs used for that work have been deleted. Keep
the production Postgres shape in the Explorer repo SQL and docs; design the next
database-change runner only when a real schema change is needed.

The current Explorer API refactor removes CHM from the write path:

- Public Explorer image: serves `/explorer` in read-only mode and redacts
  reviewer metadata, raw review JSON, route targets, and source local paths.
- Explorer admin image: serves `/explorer/admin` in author mode behind IAP and
  calls Explorer's own `/api/records` routes.
- Private Explorer API image: serves bearer-token `/api/records`
  access for agents.
- CHM image: serves the portal only and does not proxy Explorer writes.

Expected checks after routing is enabled:

```sh
curl -I https://chm.oceanagentics.org/explorer
curl -I https://chm.oceanagentics.com/explorer
curl -I https://chm.oceanagentics.org/explorer/admin
```

Unauthenticated `/explorer` requests should return the public Explorer page
without IAP. Unauthenticated `/explorer/admin` requests should be redirected by
IAP before reaching Explorer admin. Authenticated browser loading of real
Explorer graph data has been confirmed. After deploying the API refactor, smoke
test direct Explorer admin review writes and bearer-token agent record writes.
