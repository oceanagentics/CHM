# CHM Security Audit

Last updated: 2026-08-28

## Scope

This audit covers the CHM repository, Terraform configuration, deployment notes,
and the last-known CHM production setup in Google Cloud project `chm-network`.

Current production scope:

- CHM Node.js and Express app exposing `/`, `/login`, and `/healthz`.
- Cloud Run service `chm` in `us-east4`.
- External HTTPS Application Load Balancer for `chm.oceanagentics.org` and
  `chm.oceanagentics.com`.
- Google IAP protecting CHM application routes for `domain:oceanagentics.com`.
- Terraform-managed infrastructure in `infra/`.
- Explorer service accounts, database secrets, Cloud SQL infrastructure, and
  `/explorer` routing are live; treat Explorer as security-gated until the
  remaining Explorer checks are complete.

This document records repo and configuration findings. A live Cloud Asset
Inventory export should be attached or referenced before treating this as a
complete cloud-environment audit.

## Summary

CHM has a solid first production security baseline: IAP is the primary access
boundary, direct Cloud Run ingress is restricted, HTTPS is enforced at the load
balancer, the app validates signed IAP JWT assertions, Terraform pins deployed
images by digest, Cloud SQL deletion protection is enabled, and Cloud Build uses
a dedicated service account.

The main remaining work is focused: decide whether to enable Explorer app-level
IAP JWT validation and resolve the approved-but-blocked unused API cleanup.

Legacy public infrastructure cleanup completed on 2026-08-28:

- Deleted terminated Compute VM `chm-network-vm` in `us-west1-b`.
- Deleted attached 30 GB boot disk `chm-network-vm`.
- Deleted bucket `gs://chm-network-public-288836337031` and its 4 objects.
- Deleted broad default VPC firewall rules: `chm-network-allow-web`,
  `default-allow-icmp`, `default-allow-internal`, `default-allow-rdp`, and
  `default-allow-ssh`.
- Removed the default Cloud Build service account project-level
  `roles/cloudbuild.builds.builder` grant.
- Deleted stale Network Management connectivity tests `ssh-troubleshoot-1g5pc`
  and `ssh-troubleshoot-wsqtm`.
- Deleted obsolete failed Explorer Cloud Run jobs `explorer-import`,
  `explorer-api-probe`, and `explorer-api-probe2`.
- Added basic Cloud Monitoring alerting through Terraform for IAP failures,
  Cloud Run 5xx spikes, IAM policy changes, and service-account key creation.
- Confirmed Cloud Monitoring email delivery to `danny@oceanagentics.com` with
  an IAP authentication failure alert on 2026-08-28.
- Enabled Cloud SQL platform deletion protection for instance `chm`.
- Tightened Explorer database privileges so only `explorer_migration` can create
  schema objects.

## Findings

| ID | Severity | Status | Finding | Recommended action |
| --- | --- | --- | --- | --- |
| CHM-SEC-001 | High | Completed; follow-ups open | Cloud Asset Inventory was enabled through Terraform and reviewed. It found no remaining Compute VM, no persistent disks, and no legacy public website bucket. Current live resources include CHM Cloud Run, the CHM load balancer, Artifact Registry, two active managed certs, three Storage buckets, the default VPC, Explorer Cloud Run services, Explorer jobs, Explorer service accounts, Explorer database secrets, Cloud SQL, and several enabled APIs outside the CHM/Explorer surface. | Keep Cloud Asset Inventory enabled. Repeat CAI review before major production changes. Track follow-up findings for unused APIs and Explorer data infrastructure separately. |
| CHM-SEC-002 | Medium | Accepted; monitor | Project IAM currently has `user:danny@oceanagentics.com` as `roles/owner`, Google service-agent roles, `roles/logging.logWriter` for CHM/Explorer build service accounts, and `roles/cloudsql.client` for Explorer runtime service accounts. No user-managed service-account keys were found. The default Cloud Build service account's project-level `roles/cloudbuild.builds.builder` grant was removed on 2026-08-28. Danny's project Owner grant is accepted as the current operator path. | Avoid adding more primitive roles. Keep all builds on dedicated per-app build service accounts. Revisit the Owner grant if additional operators are added or if a break-glass-only model becomes practical. |
| CHM-SEC-003 | High | Completed; deployed | CHM depends on `IAP_JWT_AUDIENCE` for app-level IAP JWT validation. Terraform sets it, and the app now fails creation in production if the value is missing. Deployed on 2026-08-28 as image `us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:83f98d262f9a14aef67f9a0f2f626a0e06859a949258ca1887845c7049dfbff8`; Cloud Run revision `chm-00006-blf` is ready and serving 100% traffic. | Keep `NODE_ENV=production` and `IAP_JWT_AUDIENCE` in Terraform. Keep the fail-closed test in the CHM test suite. |
| CHM-SEC-004 | High | Mitigated; verify | Direct Cloud Run bypass appears controlled. Terraform restricts `chm` ingress to internal and Cloud Load Balancing and grants `roles/run.invoker` to the IAP service agent rather than `allUsers`. | Keep Cloud Run ingress restricted. Periodically verify the default `run.app` URL cannot serve CHM without the load balancer/IAP path. Apply the same rule to Explorer services. |
| CHM-SEC-005 | Medium | Mitigated; verify | HTTP-to-HTTPS redirect is configured at the load balancer, and HTTPS requests are protected by IAP. This reduces accidental plaintext access. | Verify port 80 redirects for both hostnames after each load-balancer change. Keep Helmet security headers enabled, and verify HSTS on authenticated HTTPS responses. |
| CHM-SEC-006 | Medium | Accepted for now | Cloud Armor rate limiting and WAF rules are not configured. This was intentionally deferred because CHM is currently small and IAP-protected. | Revisit Cloud Armor when traffic grows, when unauthenticated public routes are added, or before onboarding higher-risk apps. Start with baseline DDoS/WAF logging before enforcing blocks. |
| CHM-SEC-007 | Medium | Mitigated; verified channel | Load-balancer logging is enabled in Terraform. Cloud Logging has `_Default` retention of 30 days and locked `_Required` retention of 400 days. Terraform manages an email notification channel for `danny@oceanagentics.com` and alert policies for repeated IAP failures, Cloud Run 5xx spikes, IAM policy changes, and service-account key creation. Email delivery was confirmed by the IAP authentication failure alert received on 2026-08-28 at 05:41 UTC. Security Command Center is not in the enabled API list. | Alerts surface as Cloud Monitoring incidents under Monitoring > Alerting and notify the configured email channel. Review Security Command Center availability before broader production use. |
| CHM-SEC-008 | Medium | Mitigated; verified | Cloud Build now uses `chm-build-sa` instead of the default Compute service account. Artifact Registry writer access is limited to CHM and Explorer build service accounts, and submitter impersonation is limited to `user:danny@oceanagentics.com`. | Keep build service accounts per app. Grant only source read, Artifact Registry write, log write, and explicit submitter impersonation. Do not grant project `Editor` to build identities. |
| CHM-SEC-009 | Medium | Mitigated; accepted | Explorer database password secrets exist in Secret Manager: `explorer-db-read-password`, `explorer-db-write-password`, and `explorer-db-migration-password`. Generated secret values also exist in Terraform state. The Terraform state bucket has uniform bucket-level access and bucket IAM currently grants only `roles/storage.admin` to `user:danny@oceanagentics.com`. Secret access is narrow: read password to `explorer-sa`, write password to `explorer-api-sa`, and migration password to `explorer-migration-sa`. Live Secret Manager checks on 2026-08-28 show version `2` enabled and version `1` destroyed for all three secrets. | Treat Terraform state as sensitive. Keep bucket versioning and uniform access. Avoid granting project-level Viewer/Editor broadly. No immediate rotation is required unless access expands, compromise is suspected, or the privilege model changes materially. |
| CHM-SEC-010 | High | Completed; verified | Explorer database table-level grants are directionally correct, and runtime services use separate DB users: browser-facing `explorer` uses `explorer_read`; private `explorer-api` uses `explorer_write`; migration jobs use `explorer_migration`. Authenticated CHM users still get app-mediated writes through `explorer-api`; this finding was only about schema-object creation. In PostgreSQL, `public` is the default schema name inside the private database, not public internet access. Root cause: Cloud SQL-created users were members of `cloudsqlsuperuser`, and that inherited role had schema `CREATE`. On 2026-08-28, the live database fix removed `cloudsqlsuperuser`, `CREATEDB`, and `CREATEROLE` from `explorer_read` and `explorer_write`; revoked database/schema `CREATE` from read/write and `PUBLIC`; preserved table read/write grants; and left schema `CREATE` only on `explorer_migration`. Post-fix probes verified `explorer_read` can select but cannot insert or create tables; `explorer_write` can insert rows in a rolled-back transaction but cannot create tables; and `explorer_migration` can create tables in a rolled-back transaction. Cloud SQL row-count checks still verified `102` sources, `117` nodes, `139` edges, `10` ryu routes, and `2` saved views. | Keep the Ryu migration SQL as the source of truth for these grants. Re-run read/write/migration privilege probes after future Cloud SQL user recreation, schema migrations, or role changes. |
| CHM-SEC-011 | Medium | Mitigated; monitor | The private Explorer API path depends on Cloud Run IAM plus CHM-forwarded user context. Live checks verified `explorer-api` has internal-only ingress, direct unauthenticated `run.app` requests return a Google platform `404`, and Cloud Run `roles/run.invoker` is granted only to `serviceAccount:chm-sa@chm-network.iam.gserviceaccount.com`. Ryu server tests pass for public-mode write denial, API-mode missing-user denial, and CHM-mediated write allowance. | Keep `explorer-api` internal-only with `roles/run.invoker` granted only to `chm-sa`. Treat the `x-chm-caller-service-account` header as defense-in-depth only; Cloud Run IAM is the real caller boundary. Repeat production smoke tests when changing authenticated Explorer write workflows. |
| CHM-SEC-012 | Low | Accepted for now; verified | IAP access is granted to the full Ocean Agentics Workspace domain. This matches the locked decision, but it is broader than an app-specific Google Group. Live IAP policy on `chm-web-backend` grants only `roles/iap.httpsResourceAccessor` to `domain:oceanagentics.com`. | Keep `domain:oceanagentics.com` while CHM is an internal company portal. Move to a group such as `group:chm-users@oceanagentics.com` if access needs to become narrower. |
| CHM-SEC-013 | Low | Mitigated; monitor | `/healthz` is intentionally unauthenticated for Cloud Run startup probes. It currently returns only a minimal status payload. | Keep `/healthz` free of build metadata, environment details, dependency status, and user information. Do not add sensitive diagnostics to this route. |
| CHM-SEC-014 | Low | Mitigated; monitor | The container runs as the non-root `node` user and production dependencies are installed with `npm ci --omit=dev`. Terraform deploys immutable image digests. | Continue running `npm test` and `npm audit --omit=dev` before builds. Keep deploying by digest rather than mutable tags. Consider vulnerability scanning before broader production use. |
| CHM-SEC-015 | Low | Open | DNS is intentionally manual in Dynadot. Terraform cannot detect drift in `chm.oceanagentics.org` or `chm.oceanagentics.com` records. | Document DNS changes in `docs/deploy.md`, verify both A records after load-balancer changes, and consider registrar account hardening such as MFA and least-privilege access. |
| CHM-SEC-016 | High | Closed | Legacy public infrastructure existed outside Terraform: terminated VM `chm-network-vm`, attached 30 GB disk, and website bucket `chm-network-public-288836337031` containing old static artifacts including `bootstrap.public.json`. | Completed on 2026-08-28. VM, disk, bucket, and bucket objects were deleted and verified as not found. |
| CHM-SEC-017 | Medium | Closed | The default VPC had broad enabled firewall rules: `chm-network-allow-web`, `default-allow-icmp`, `default-allow-internal`, `default-allow-rdp`, and `default-allow-ssh`. No active Compute instances or disks remained, but future accidental VMs would have inherited risky access. | Completed on 2026-08-28. All five broad default VPC firewall rules were deleted and verified absent. Consider deleting the default VPC and auto-created subnets later if no future Compute/VPC workloads need them. |
| CHM-SEC-018 | Low | Closed | Cloud Asset Inventory found stale Network Management connectivity tests `ssh-troubleshoot-1g5pc` and `ssh-troubleshoot-wsqtm`, likely from legacy SSH troubleshooting. They did not expose traffic, but they were unmanaged audit noise. | Completed on 2026-08-28. Both stale connectivity tests were deleted and verified absent. |
| CHM-SEC-019 | Low | Approved; blocked without force | Cloud Asset Inventory found many enabled Google APIs outside the CHM/Explorer surface. Service-specific checks found no BigQuery datasets, Pub/Sub topics, Pub/Sub subscriptions, Firestore database, Dataform repository, or Dataplex lake. Current CHM and Explorer code/Terraform checks found no need for Analytics Hub, the BigQuery family, Dataform, Dataplex, Datastore, Pub/Sub, Cloud Trace, Container Registry, Network Management, or OS Login. Disablement of the exact candidate list was approved on 2026-08-28 with the constraint to avoid `--force`. A no-force disable attempt stopped immediately because Service Usage reported `analyticshub.googleapis.com` is depended on by active service `cloudapis.googleapis.com`; no APIs were disabled. `cloudapis.googleapis.com` is a Google Cloud API meta service in the baseline/dependency list. | Do not force-disable the APIs by default. Review the `cloudapis.googleapis.com` dependency before any further disable attempt, and only proceed if the impact is explicitly accepted. Keep intentional APIs managed in Terraform. |
| CHM-SEC-020 | Medium | Open | Explorer's browser-facing service is protected by load-balancer IAP and restricted Cloud Run ingress, but it does not currently set `IAP_JWT_AUDIENCE`, so Explorer is not performing its own app-level IAP JWT validation. The Explorer backend service ID is now known: `4582439918390522076`. | Apply Terraform with `explorer_iap_backend_service_id=4582439918390522076` so Explorer validates the signed IAP assertion at the app layer. Consider making Ryu fail closed in production when app-level IAP validation is required but the audience is missing. |
| CHM-SEC-021 | Medium | Completed; verified | Cloud SQL instance `chm` is private-only. Terraform has resource-level `deletion_protection = true` and now sets the Cloud SQL platform flag `settings.deletion_protection_enabled = true`. A live `gcloud sql instances describe chm` check returned `True` on 2026-08-28. Terraform deletion protection blocks Terraform-driven destruction; the Cloud SQL platform flag protects against console/API deletion outside Terraform. | Keep both deletion-protection settings enabled for production. Disable them only as part of an explicit, reviewed teardown. |

## Enabled API Review

Intentionally managed by Terraform for the running CHM and Explorer stack:

- `artifactregistry.googleapis.com`: container images for CHM and Explorer.
- `cloudasset.googleapis.com`: asset inventory for security review.
- `cloudbuild.googleapis.com`: image builds.
- `cloudresourcemanager.googleapis.com`: project and IAM policy management.
- `compute.googleapis.com`: HTTPS load balancer, global IP, certificates, NEGs,
  and Cloud SQL private networking.
- `iap.googleapis.com`: Identity-Aware Proxy.
- `iam.googleapis.com`: service accounts and IAM bindings.
- `iamcredentials.googleapis.com`: service-account token generation for trusted
  service-to-service calls.
- `logging.googleapis.com`: Cloud Logging and log-based alerts.
- `monitoring.googleapis.com`: Cloud Monitoring notification channel and alerts.
- `run.googleapis.com`: Cloud Run services and jobs.
- `secretmanager.googleapis.com`: Explorer database secrets.
- `servicenetworking.googleapis.com`: private services access for Cloud SQL.
- `sqladmin.googleapis.com`: Cloud SQL instance, database, and users.
- `storage.googleapis.com`: Terraform state bucket and Cloud Build source
  buckets.

Google baseline or dependency APIs to leave alone unless a later review proves
they can be safely disabled:

- `cloudapis.googleapis.com`
- `orgpolicy.googleapis.com`
- `servicemanagement.googleapis.com`
- `serviceusage.googleapis.com`
- `sql-component.googleapis.com`
- `storage-api.googleapis.com`
- `storage-component.googleapis.com`
- `telemetry.googleapis.com`

Approved disable candidates, blocked by the `cloudapis.googleapis.com`
dependency when attempted without `--force`:

- `analyticshub.googleapis.com`
- `bigquery.googleapis.com`
- `bigqueryconnection.googleapis.com`
- `bigquerydatapolicy.googleapis.com`
- `bigquerydatatransfer.googleapis.com`
- `bigquerymigration.googleapis.com`
- `bigqueryreservation.googleapis.com`
- `bigquerystorage.googleapis.com`
- `cloudtrace.googleapis.com`
- `containerregistry.googleapis.com`
- `dataform.googleapis.com`
- `dataplex.googleapis.com`
- `datastore.googleapis.com`
- `networkmanagement.googleapis.com`
- `oslogin.googleapis.com`
- `pubsub.googleapis.com`

## Recommended Next Actions

1. Decide whether to enable Explorer app-level IAP JWT validation with backend
   service ID `4582439918390522076`.
2. Resolve the CHM-SEC-019 API dependency block. The candidate list is approved
   for disablement, but the no-force attempt was blocked by
   `cloudapis.googleapis.com`; do not force it without a separate decision.

## Evidence Reviewed

- `README.md`
- `docs/server-migration.md`
- `docs/terraform-planning.md`
- `docs/deploy.md`
- `src/server.js`
- `cloudbuild.yaml`
- `Dockerfile`
- `infra/`
- Targeted live `gcloud` inventory and IAM checks on 2026-08-28
- Firewall and default Cloud Build access cleanup on 2026-08-28
- Stale Network Management connectivity-test cleanup and API review on 2026-08-28
- Cloud Monitoring email alert receipt on 2026-08-28
- Cloud SQL deletion-protection apply and verification on 2026-08-28
- Explorer database checks `explorer-db-check-7gpt7` and
  `explorer-db-check-qx72c` on 2026-08-28
- No-force CHM-SEC-019 API disable attempt on 2026-08-28; blocked by
  `cloudapis.googleapis.com` dependency before any API was disabled
- Live Explorer database privilege fix on 2026-08-28; verified by
  `explorer-priv-fix-20260828-vxmdz`,
  `explorer-priv-fix-20260828-zcl96`,
  `explorer-priv-fix-20260828-6hfws`, and
  `explorer-priv-fix-20260828-wj97t`
