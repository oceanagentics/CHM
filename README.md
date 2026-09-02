# CHM

CHM is the Ocean Agentics portal for authenticated, path-mounted CHM applications.
It is intended to be the shared entry point, login boundary, application switcher,
and loader for apps served from `chm.oceanagentics.org` and
`chm.oceanagentics.com`.

Explorer lives under `/explorer`. Terraform keeps the Explorer slice gated by
`enable_explorer`, and the current live project has that slice applied with
built Explorer images, database role hardening, public read-only routing,
IAP-protected admin routing, private API access controls, and app-level IAP JWT
validation on the protected routes.

## What Exists Today

The current CHM app is a minimal Node.js and Express portal shell.

- `/` serves the CHM portal.
- `/login` relies on Google IAP for unauthenticated login and redirects
  authenticated users to `/`.
- `/healthz` returns `{ "status": "ok" }` for Cloud Run startup probes.
- `/explorer` routes to the public read-only Explorer backend.
- `/explorer/admin` routes to the IAP-protected Explorer admin backend.
- CHM does not proxy Explorer writes. Explorer handles direct
  IAP-authenticated browser writes and bearer-token agent API access itself.

The CHM app validates Google IAP signed JWT assertions for protected app routes,
and Explorer admin is configured to do the same. Ocean Agentics Workspace users
are required for protected routes, security headers are sent with Helmet, and
containers run as non-root users.

## What Is Running

Last verified: August 31, 2026.

- Google Cloud project: `chm-network`
- Primary region: `us-east4`
- Cloud Run service: `chm`
- Runtime service account: `chm-sa@chm-network.iam.gserviceaccount.com`
- Build service account: `chm-build-sa@chm-network.iam.gserviceaccount.com`
- Image: `us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:163707f86945c620d99b2e709dc2bb883b9fe8f89102764fe27c77065f18c4bc`
- Cloud Run revision: `chm-00011-gf8`
- Scaling: 1 minimum instance, 3 maximum instances
- Direct VPC egress: default `us-east4` subnet, `all-traffic`
- Default `us-east4` subnet: Terraform-imported with Private Google Access
  enabled and `deletion_policy = "ABANDON"`
- Explorer Cloud Run services: public `explorer`, IAP-protected
  `explorer-admin`, and private `explorer-api`
- Explorer source commit: `4198b8c`
- Explorer public Cloud Run revision: `explorer-00014-hwg`
- Explorer admin Cloud Run revision: `explorer-admin-00004-rxr`
- Explorer API Cloud Run revision: `explorer-api-00013-rwh`
- Explorer public image: `us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-public@sha256:16f866c2170bd91b53784c995eec2eeee2d71d2910aae5b2e7d2580d60bd8742`
- Explorer admin image: `us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-admin@sha256:9bdeddb6a704a80b91cbd80289e255616a2504732235ce2f07cc4c9e37c4d98e`
- Explorer admin IAP JWT audience: `/projects/288836337031/global/backendServices/5570063593656309274`
- Cloud SQL instance: `chm`, database `explorer`
- Cloud SQL deletion protection: Terraform and Cloud SQL platform flag enabled
- Load balancer IP: `34.110.145.254`
- Hostnames: `chm.oceanagentics.org`, `chm.oceanagentics.com`
- Managed certificates: `chm-oceanagentics-org-cert`,
  `chm-oceanagentics-com-cert`
- IAP access: `domain:oceanagentics.com`
- CHM admin hint emails: `danny@oceanagentics.com`
- Admin redirect hint cookie: `chm_admin_hint`
- Alerts: confirmed Cloud Monitoring email channel `danny@oceanagentics.com` for IAP
  failures, Cloud Run 5xx spikes, IAM policy changes, and service-account key
  creation
- Terraform state: `gs://chm-network-tfstate-288836337031/chm`

Load-balanced Cloud Run services are restricted to internal and Cloud Load
Balancing ingress, so the default `run.app` URLs should not bypass the load
balancer. HTTP port 80 redirects to the matching HTTPS URL. Cloud Run and Cloud
SQL deletion protection are enabled. Public DNS for both hostnames resolves to
the load balancer IP; unauthenticated HTTPS requests to CHM and Explorer admin
are intercepted by IAP.

Terraform keeps the Explorer slice behind `enable_explorer=false` by default for
fresh/bootstrap applies, but the live CHM project currently runs it with
`enable_explorer=true`.

Public Explorer shows record depth and review state without edit controls.
Explorer admin owns its own direct IAP-authenticated review and record write
calls. Agent writes go to Explorer's bearer-token record API, not through CHM.

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
