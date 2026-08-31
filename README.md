# CHM

CHM is the Ocean Agentics portal for authenticated, path-mounted CHM applications.
It is intended to be the shared entry point, login boundary, application switcher,
and loader for apps served from `chm.oceanagentics.org` and
`chm.oceanagentics.com`.

Explorer lives under `/explorer`. Terraform keeps the Explorer slice gated by
`enable_explorer`, and the current live project has that slice applied with a
built Explorer image, database role hardening, private API access controls, and
app-level IAP JWT validation.

## What Exists Today

The current CHM app is a minimal Node.js and Express portal shell.

- `/` serves the CHM portal.
- `/login` relies on Google IAP for unauthenticated login and redirects
  authenticated users to `/`.
- `/healthz` returns `{ "status": "ok" }` for Cloud Run startup probes.
- `/explorer` routes to the Explorer backend behind IAP.
- `PATCH /api/explorer/nodes/:id/review` is the only CHM browser-write proxy
  to the private Explorer API.

The app validates Google IAP signed JWT assertions for app routes, Explorer is
configured to do the same, Ocean Agentics Workspace users are required, security
headers are sent with Helmet, and containers run as non-root users.

## What Is Running

Last verified: August 31, 2026.

- Google Cloud project: `chm-network`
- Primary region: `us-east4`
- Cloud Run service: `chm`
- Runtime service account: `chm-sa@chm-network.iam.gserviceaccount.com`
- Build service account: `chm-build-sa@chm-network.iam.gserviceaccount.com`
- Image: `us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:a696db7b949cde2fe2c4fa9e65179b16383ea37f3942fa54b87981f1828e6ff3`
- Cloud Run revision: `chm-00009-wkz`
- Scaling: 1 minimum instance, 3 maximum instances
- Direct VPC egress: default `us-east4` subnet, `all-traffic`
- Default `us-east4` subnet: Terraform-imported with Private Google Access
  enabled and `deletion_policy = "ABANDON"`
- Explorer Cloud Run services: `explorer` and private `explorer-api`
- Explorer Cloud Run revision: `explorer-00011-kxh`
- Explorer API Cloud Run revision: `explorer-api-00010-spd`
- Explorer image: `us-east4-docker.pkg.dev/chm-network/chm-apps/explorer@sha256:cb1395e8fbf3707089f57367a5e5b3809a5f3a222a6387c729752aaf69e1edba`
- Explorer IAP JWT audience: `/projects/288836337031/global/backendServices/4582439918390522076`
- Cloud SQL instance: `chm`, database `explorer`
- Cloud SQL deletion protection: Terraform and Cloud SQL platform flag enabled
- Load balancer IP: `34.110.145.254`
- Hostnames: `chm.oceanagentics.org`, `chm.oceanagentics.com`
- Managed certificates: `chm-oceanagentics-org-cert`,
  `chm-oceanagentics-com-cert`
- IAP access: `domain:oceanagentics.com`
- Alerts: confirmed Cloud Monitoring email channel `danny@oceanagentics.com` for IAP
  failures, Cloud Run 5xx spikes, IAM policy changes, and service-account key
  creation
- Terraform state: `gs://chm-network-tfstate-288836337031/chm`

The Cloud Run service is restricted to internal and Cloud Load Balancing ingress,
so the default `run.app` URL should not bypass IAP. HTTP port 80 redirects to the
matching HTTPS URL at the load balancer. Cloud Run and Cloud SQL deletion
protection are enabled. Public DNS for both hostnames resolves to the load
balancer IP, and unauthenticated HTTPS requests are intercepted by IAP.

Terraform keeps the Explorer slice behind `enable_explorer=false` by default for
fresh/bootstrap applies, but the live CHM project currently runs it with
`enable_explorer=true`.

CHM and Explorer now narrow the Explorer browser write surface to the node
review path above. Explorer's details UI shows record depth and review state to
all users, and authenticated/author builds provide the review-state dropdown
plus reviewer-note form. A private API probe verified the narrow review write
and denial cases; the remaining manual check is the signed-in browser form
click-through.

## Development

```sh
npm install
npm test
npm start
```

The local app does not require IAP unless `IAP_JWT_AUDIENCE` is set.

## Deployment

Build images with the dedicated CHM Cloud Build service account:

```sh
gcloud builds submit --region us-east4 --config cloudbuild.yaml .
```

Deploy by immutable image digest through Terraform:

```sh
cd infra
terraform plan -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<image-digest>
terraform apply -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<image-digest>
```

See `docs/deploy.md` for the full bootstrap and deployment sequence.

## Agent Notes

Before changing infrastructure, IAP, Cloud Run, app routing, login behavior, or
Terraform, read:

- `docs/server-migration.md`
- `docs/terraform-planning.md`
- `docs/deploy.md`

Use the Ocean Agentics SSH remote for GitHub pushes:

```sh
git@github-oceanagentics:oceanagentics/CHM.git
```

Avoid console-only infrastructure edits after Terraform owns a resource. If a
manual console change is unavoidable, reflect it in Terraform or import it before
continuing.
