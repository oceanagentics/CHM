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
Explorer path split on 2026-08-31; localization review proxy and Explorer
language migration rollout on 2026-09-01:

- Project: `chm-network`
- Region: `us-east4`
- Cloud Run service: `chm`
- Image: `us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:1e41b1d4ae72588f00fe82220ae71c70cd25f377cad3dd7a9c5f3f200b714caa`
- CHM Cloud Run revision: `chm-00012-8h7`
- Scaling: 1 minimum instance, 3 maximum instances
- Cloud Run deletion protection: enabled
- CHM Direct VPC egress: default `us-east4` subnet, `all-traffic`
- Default `us-east4` subnet: Terraform-imported with Private Google Access
  enabled and `deletion_policy = "ABANDON"`
- Cloud SQL deletion protection: Terraform and Cloud SQL platform flag enabled
- Cloud Build service account: `chm-build-sa@chm-network.iam.gserviceaccount.com`
- Explorer Cloud Run services: public `explorer`, IAP-protected
  `explorer-admin`, and private `explorer-api`
- Explorer source commit: `226fc2c`
- Explorer public Cloud Run revision: `explorer-00015-dc9`
- Explorer admin Cloud Run revision: `explorer-admin-00005-p9k`
- Explorer API Cloud Run revision: `explorer-api-00014-jb8`
- Explorer public image: `us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-public@sha256:9742be1c20233a44f4fd235132aa414fa1488bd198562ce396f2c311633e109c`
- Explorer admin image: `us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-admin@sha256:f9e46cb5da233cb3becaf014ffc3ba3bb15a94363e05d756b4a3da4a66f19d84`
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

Terraform reported no drift on 2026-09-01 with the currently deployed image
digests:

```sh
cd /Users/danvallentyne/dev/CHM/infra
terraform plan \
  -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:1e41b1d4ae72588f00fe82220ae71c70cd25f377cad3dd7a9c5f3f200b714caa \
  -var 'chm_admin_hint_emails=["danny@oceanagentics.com"]' \
  -var enable_explorer=true \
  -var explorer_image=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-public@sha256:9742be1c20233a44f4fd235132aa414fa1488bd198562ce396f2c311633e109c \
  -var explorer_admin_image=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-admin@sha256:f9e46cb5da233cb3becaf014ffc3ba3bb15a94363e05d756b4a3da4a66f19d84 \
  -var explorer_admin_iap_backend_service_id=5570063593656309274
```

Public DNS now points both CHM hostnames at the load balancer. Unauthenticated
HTTPS requests to `/` and `/explorer/admin` should go to the Google IAP login
flow. Unauthenticated `/explorer` should serve the public read-only Explorer
view.

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

Then build the public and admin Explorer images from the Ryu repo:

```sh
cd /Users/danvallentyne/dev/oceanagentics/ryu
gcloud builds submit \
  --region us-east4 \
  --config cloudbuild.yaml \
  --substitutions _IMAGE=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-public:$(git rev-parse --short HEAD),_APP_BASE_PATH=/explorer,_VITE_APP_MODE=public,_VITE_CAN_REVIEW_NODES=false,_VITE_REVIEW_API_BASE_PATH=/api/explorer \
  .
gcloud builds submit \
  --region us-east4 \
  --config cloudbuild.yaml \
  --substitutions _IMAGE=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-admin:$(git rev-parse --short HEAD),_APP_BASE_PATH=/explorer/admin,_VITE_APP_MODE=author,_VITE_CAN_REVIEW_NODES=true,_VITE_REVIEW_API_BASE_PATH=/api/explorer \
  .
```

Then apply the gated Explorer infrastructure:

```sh
cd /Users/danvallentyne/dev/CHM/infra
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

The current review UI/API update is deployed:

- Public Explorer image: serves `/explorer` in read-only mode and redacts
  reviewer metadata, raw review JSON, route targets, and source local paths.
- Explorer admin image: serves `/explorer/admin` in author mode behind IAP.
- Private Explorer API image: serves the narrow
  `PATCH /explorer/api/nodes/:id/localizations/:locale/review` mutation.
- CHM image: proxies only `PATCH /api/explorer/nodes/:id/localizations/:locale/review` to the private
  Explorer API.

The CHM service needs Direct VPC egress with `all-traffic`, and the default
`us-east4` subnet needs Private Google Access enabled, so CHM service-to-service
requests to the internal-only `explorer-api` are treated as internal traffic.

Expected checks after routing is enabled:

```sh
curl -I https://chm.oceanagentics.org/explorer
curl -I https://chm.oceanagentics.com/explorer
curl -I https://chm.oceanagentics.org/explorer/admin
```

Unauthenticated `/explorer` requests should return the public Explorer page
without IAP. Unauthenticated `/explorer/admin` requests should be redirected by
IAP before reaching Explorer admin. Authenticated browser loading of real
Explorer graph data has been confirmed.
The private backend review path was verified on 2026-08-31 by a temporary Cloud
Run probe running as `chm-sa` against the clean committed image: it updated
`fishbase` as `danny@oceanagentics.com`, rejected unsupported fields, rejected
missing user context, rejected the wrong caller header, and confirmed the
general node write route is absent. The remaining browser-only check is selecting a node in a
signed-in CHM/IAP session, editing review state or reviewer note, and confirming
the UI shows the persisted `reviewState`, `reviewerNote`, `reviewer`, and
`lastReviewed` fields.
