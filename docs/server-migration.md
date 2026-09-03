# CHM Server Migration Notes

Source plan: `/Users/danvallentyne/dev/oceanagentics/CHM-Network/outputs/ryu-cloud-run-migration-plan.md`

## Purpose

CHM is the official user-facing entry app, application switcher, loader, and IAP-protected portal for `chm.oceanagentics.org` and `chm.oceanagentics.com`.

Explorer, currently developed in the Ryu repo, remains the graph application and is mounted under CHM at `/explorer`.

## Current Status

The first CHM slice was deployed on 2026-08-26. The Explorer infrastructure
slice was applied on 2026-08-28. The review UI/API and CHM-to-internal-API VPC
fix and the public/admin Explorer path split were deployed on 2026-08-31. The
direct bearer-token Explorer record API was deployed on 2026-09-03. The live
services now have IAP JWT validation on protected routes, database role
separation, public read-only Explorer graph loading, IAP-protected Explorer
admin writes, and bearer-token agent reads/writes at `/api/records`. Explorer
shows record depth and review state to all users, and exposes an
authenticated/author review form for review state and reviewer note updates at
`/explorer/admin`.

- Cloud Run service `chm` is deployed in `us-east4`.
- Terraform state is stored in `gs://chm-network-tfstate-288836337031/chm`.
- The HTTPS load balancer IP is `34.110.145.254`.
- The default `us-east4` subnet is imported into Terraform with Private Google
  Access enabled and `deletion_policy = "ABANDON"`.
- Dynadot DNS has `A` records for `chm.oceanagentics.org` and `chm.oceanagentics.com` pointing to `34.110.145.254`.
- Public HTTPS requests to `/` and `/explorer/admin` reach Google IAP.
- `/explorer` routing is public read-only when Terraform is applied with
  `enable_explorer=true`.
- Terraform includes the Explorer slice: shared Cloud SQL `chm`, database
  `explorer`, Explorer service accounts, generated database-password secrets,
  public Cloud Run `explorer`, IAP-protected Cloud Run `explorer-admin`,
  bearer-token Cloud Run `explorer-api`, and `/explorer`, `/explorer/admin`,
  and `/api/records` URL-map routing.
- Current CHM deployment: CHM commit `07dd201`, Cloud Run revision
  `chm-00013-lvp`, image
  `us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:a02418369050dfb52f5eba561df32628f6116ddc9c6f1a002d31ba7582c2c90e`.
- Current Explorer deployment: Ryu commit `d6b6992`, public revision
  `explorer-00018-7qw`, admin revision `explorer-admin-00008-qz9`, API
  revision `explorer-api-00016-bpt`, public image
  `us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-public@sha256:25e761049522571b0f0fb0521830c54418b8d12dca5ee91a9842d200bfe40ab5`,
  admin image
  `us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-admin@sha256:09c40f273c50c00d13b9a30ec1109a16da224b3729a054b22b0ec01b5a56d07f`,
  and API image
  `us-east4-docker.pkg.dev/chm-network/chm-apps/explorer-api@sha256:0f6c8ae7c27e8d97964c571d40b418d04722afdd5e0364757424956e747a6c6e`.
- Authenticated browser verification confirmed Explorer loads real graph data.
- Live `/api/records` smoke on 2026-09-03 verified unauthenticated
  `401 missing_bearer_token`, invalid bearer `403 invalid_bearer_token`,
  writer-token read `200`, `validateOnly` write preflight `200`, and a
  throwaway record create/delete cycle with final cleanup.
- Unmanaged Explorer Cloud Run setup/check jobs were deleted after launch
  setup and verification.

## Target Routes

Use one shared domain with path routing:

- `https://chm.oceanagentics.org/` routes to CHM.
- `https://chm.oceanagentics.org/login` routes to CHM and should trigger or forward to the IAP login flow, not implement a separate CHM password screen.
- `https://chm.oceanagentics.org/explorer` routes to public read-only Explorer.
- `https://chm.oceanagentics.org/explorer/admin` routes to IAP-protected Explorer admin.
- `https://chm.oceanagentics.org/api/records` routes to Explorer API and requires a Ryu bearer token.
- `https://chm.oceanagentics.com/`, `/login`, `/explorer`, `/explorer/admin`, and `/api/records` route to the same CHM-managed load balancer and explicit app backends.
- Future CHM apps use their own path prefixes, for example `/otherapp1` and `/otherapp2`.

`/` and `/login` are IAP-protected. The first implementation should treat IAP as the shared Google login boundary and avoid building a separate user-auth system.
CHM sets the `chm_admin_hint` cookie for emails in `CHM_ADMIN_HINT_EMAILS`.
Public Explorer uses only that hint to redirect known admins from `/explorer` to
`/explorer/admin` before mounting the graph.

## Locked Decisions

- Infrastructure should be managed with Terraform, not console-only setup.
- URL routing should use explicit URL map rules per app, not URL mask routing.
- IAP access should be granted to Ocean Agentics Workspace users with the principal `domain:oceanagentics.com`.
- `/` and `/login` are IAP-protected CHM routes.
- `/login` should trigger or forward to the IAP login flow instead of implementing a separate CHM login form.
- The minimal CHM app exposes `/`, `/login`, and `/healthz`.
- The minimal CHM app stack is Node.js and Express.
- The primary Cloud Run region is `us-east4`.
- DNS is managed manually in Dynadot, not Terraform.
- `chm.oceanagentics.com` is served as an additional CHM hostname, not redirected.
- HTTP requests redirect to the same host and path on HTTPS at the load balancer.
- CHM validates the signed IAP JWT assertion for app routes, except `/healthz` for Cloud Run startup probes.
- CHM sets the `chm_admin_hint` public redirect cookie for configured admin emails after IAP validation.
- Cloud Run deletion protection is enabled for the CHM service.
- Cloud Build uses the dedicated `chm-build-sa` service account instead of the default Compute service account.
- Initial Terraform-managed routes are `/` and `/login`.
- Target Explorer routes are `/explorer`, `/explorer/*`, `/explorer/admin`,
  and `/explorer/admin/*`, managed only when `enable_explorer=true`.
- The Explorer/Ryu repo now provides Cloud Run base-path compatibility for `/explorer` and `/explorer/admin`, runtime modes, a Dockerfile, Cloud Build config, PostgreSQL schema reference, and Postgres seed handling.

## CHM Owns

- The shared domain `chm.oceanagentics.org`.
- The external HTTPS Application Load Balancer.
- Google-managed TLS certificate setup.
- Serverless NEGs and backend services for CHM, Explorer, and future apps.
- URL map path routing.
- IAP setup on protected load-balancer backend services.
- IAP access policy for approved users, groups, and service accounts.
- Cloud Run service `chm`.
- CHM portal UI, `/login` route, application switcher, and app loader.
- CHM app registry for path-mounted apps.
- IAP signed JWT validation in CHM.
- Shared service-account, Secret Manager, Artifact Registry, Cloud SQL, Cloud Storage, logging, and deployment conventions.
- Shared VPC/subnet settings needed for private Cloud Run service-to-service
  calls.

CHM should not own Explorer graph logic, Explorer validation, Explorer database schema decisions, or broad Explorer write credentials.

## Explorer Handoff

Explorer/Ryu should provide CHM with:

- Route prefix: `/explorer`.
- Admin route prefix: `/explorer/admin`.
- Built public Explorer image digest for `explorer_image`.
- Built admin Explorer image digest for `explorer_admin_image`.
- Optional built Explorer API image digest for bearer-token agent access; this
  defaults to `explorer_image` when empty.
- Health check path: `/healthz`.
- Required environment variables, including `APP_BASE_PATH=/explorer|/explorer/admin`, `RYU_DATA_BACKEND=postgres`, and `RYU_MODE=public|api`.
- Required secrets and database roles: `explorer_read`, `explorer_write`, and `explorer_schema_admin`.
- Browser review calls go directly to the IAP-protected Explorer service as
  `PATCH /explorer/admin/api/records/:id/review`.
- Agent reads and writes go directly to Explorer's bearer-token record API.
- Smoke test commands for `/explorer`, `/explorer/admin`, read-only access, authorized review writes, and unauthorized denial.
- Network requirement: for an internal-only `explorer-api`, CHM must use Direct
  VPC egress through a subnet with Private Google Access enabled.

Explorer remains responsible for enforcing its own validation and database role separation even when CHM has already authenticated the user through IAP.

## Shared Guardrails

- Do not enable IAP both on a load-balancer backend service and directly on the Cloud Run service behind it.
- Restrict load-balanced Cloud Run services to internal and Cloud Load Balancing ingress so default `run.app` URLs cannot bypass IAP.
- Do not require CHM service-to-service calls for Explorer writes.
- Do not grant public unauthenticated invoke access to `chm` or `explorer-admin`.
- Do not proxy Explorer writes through CHM. Browser writes must use direct
  Explorer IAP auth, and agent writes must use Explorer bearer-token auth.
- Do not share database users or runtime secrets across apps.
- Do not let public services use writer or schema-admin credentials.
- Do not enable Cloud CDN on IAP-protected backend services.
- Do not keep standing manual Cloud Run jobs for completed launch setup work.

## First CHM Slice

1. Build the minimal CHM app routes: `/`, `/login`, and `/healthz`.
2. Make `/login` rely on IAP for unauthenticated login and redirect authenticated requests to `/`.
3. Deploy Cloud Run `chm` in `us-east4` with service account `chm-sa`.
4. Create Terraform definitions for the CHM Artifact Registry repository, Cloud Run service, load balancer, managed certificate, serverless NEG, backend service, `/` and `/login` URL map rules, and IAP policy.
5. Bootstrap the Artifact Registry repository, then build and push the CHM image before applying the full Cloud Run plan.
6. Output the load balancer IP so the `chm.oceanagentics.org` DNS `A` record can be created manually in Dynadot.
7. Restrict direct Cloud Run ingress for load-balanced services.
8. Grant only the needed invoker permissions between CHM and IAP.
9. Add `/explorer` and `/explorer/admin` routing by applying
   the gated Explorer Terraform slice with `enable_explorer=true` and real
   public/admin Explorer image digests.
