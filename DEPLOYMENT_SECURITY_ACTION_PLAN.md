# Deployment, Security, and Operations Plan

Date: 2026-04-03

## Scope

Analysis of current repository status for deployment with:
- GitHub Actions
- AWS (Terraform)
- Docker Compose

Primary code reviewed: `backend/`, `infra/`, `.github/workflows/`, root docs.  
Note: `frontend/` is currently being removed in your working tree.

## Executive Summary

The project is **not deployment-ready yet** for production with GitHub Actions + AWS + Docker Compose.

Main reasons:
1. Critical infrastructure exposure defaults in Terraform.
2. Missing deployment building blocks (no Dockerfile, no docker-compose, no CI/CD workflows).
3. Backend lacks basic API hardening (auth, validation, secure headers, safe error handling).
4. Current AWS bootstrap (`user_data.sh`) does not deploy the real application.

## Current Findings

## 1) Critical / High Risk Security Findings

1. Public API exposed to all internet:
- `infra/main.tf:87` opens TCP `3000` to `0.0.0.0/0`.

2. SSH default is globally open:
- `infra/variables.tf:9` default `allowed_ssh_cidr = "0.0.0.0/0"`.

3. RDS is publicly accessible:
- `infra/main.tf:207` sets `publicly_accessible = true`.
- `infra/main.tf:162` DB subnet group uses public subnet.

4. S3 public-access protections disabled:
- `infra/main.tf:143-146` all public access block controls are `false`.
- `infra/main.tf:155` CORS allows all origins.

5. Backend has no auth / authorization:
- All diagram routes are public in `backend/src/routes/diagrams.js`.

6. Overly permissive backend CORS:
- `backend/src/server.js:12` uses `app.use(cors())` with default `*`.

7. Error leakage to clients:
- `backend/src/controllers/diagramController.js` returns `err.message` in many `500` responses.

8. Stored XSS risk in static UI served from backend:
- Unsanitized HTML injection patterns in `backend/public/index.html` (`innerHTML` at lines 841, 988, 1123).

## 2) Deployment Blockers

1. No GitHub Actions workflow implemented:
- `.github/workflows/.gitkeep` is a placeholder.

2. No containerization files:
- No `backend/Dockerfile`.
- No `docker-compose.yml`.
- No `.dockerignore`.

3. AWS bootstrap script does not deploy app source:
- `infra/user_data.sh:24` git clone is commented.
- Script creates empty dirs and runs `npm init` (`infra/user_data.sh:26-31`), not your actual app.

4. Secrets handling is unsafe in bootstrap template:
- Hardcoded sample DB password in `infra/user_data.sh:36`.

5. Data layer mismatch for cloud deployment:
- Prisma datasource is `sqlite` in `backend/prisma/schema.prisma:6`.
- Infra is provisioning PostgreSQL in AWS.
- Existing migration SQL is SQLite-flavored.

## 3) Additional Risk Notes

1. No runtime security middleware:
- Missing `helmet`, rate limiting, request validation.

2. Dependency advisory:
- `npm audit` reports one low vulnerability in `aws-sdk` v2.
- Also, AWS SDK v2 is deprecated/end-of-support path.

3. No automated tests currently:
- `backend/package.json` has placeholder test script only.

## Recommended Target Deployment Pattern

Use this practical path first (simple and maintainable):

1. **Dockerize backend** and run on **EC2 with Docker Compose**.
2. **GitHub Actions CI**: lint/test/security scan on PR.
3. **GitHub Actions CD**:
   - Build image
   - Push to ECR
   - Deploy to EC2 (pull new image + compose up)
4. Keep **RDS private** and connect only from EC2 security group.
5. Use **AWS Secrets Manager or SSM Parameter Store** for runtime secrets.
6. Put backend behind **ALB + HTTPS** (ACM cert) before public production release.

## What We Should Do (Priority Order)

## Phase 0 - Blockers (do first)

1. Lock down Terraform network exposure:
- Restrict SSH to your IP only.
- Remove public access for RDS (`publicly_accessible = false`).
- Move DB to private subnets (at least two subnets/AZs).
- Restrict API ingress (prefer ALB security group, not world-open EC2:3000).
- Enable S3 public access block all = true.

2. Fix backend security baseline:
- Add `helmet`.
- Configure strict CORS allowlist via env var.
- Replace `err.message` client responses with generic messages.
- Add input validation (`zod`/`joi`) for all request bodies and params.
- Add auth (minimum API key or JWT, ideally JWT + ownership checks).

3. Align data layer to PostgreSQL:
- Change Prisma provider to `postgresql`.
- Recreate migrations for PostgreSQL.
- Test migration in local Docker Postgres before AWS.

## Phase 1 - Container and Local Reliability

1. Add `backend/Dockerfile`:
- Multi-stage or slim production build.
- Non-root user.
- `npm ci --omit=dev`.
- Healthcheck endpoint.

2. Add `.dockerignore`:
- Exclude `node_modules`, `.env`, git files, logs.

3. Add `docker-compose.yml` for local/dev:
- `api` service (backend image/build)
- `postgres` service (for local parity)
- Optional `adminer`/`pgadmin` for DB inspection
- Volumes and explicit env files

## Phase 2 - GitHub Actions CI/CD

1. Create CI workflow (`.github/workflows/ci.yml`):
- Trigger on PR + push main.
- Node install + `npm ci` + tests.
- `npm audit --omit=dev`.
- Optional: CodeQL + Trivy fs scan + tfsec/checkov for Terraform.

2. Create CD workflow (`.github/workflows/cd.yml`):
- Trigger on merge to `main` (or release tags).
- Authenticate to AWS using OIDC (no long-lived AWS keys in GitHub).
- Build and push Docker image to ECR.
- Deploy to EC2 using SSH/SSM:
  - pull new image
  - `docker compose up -d`
  - run health check rollback guard.

3. Add protected environments:
- `staging` and `production` with required approvals in GitHub.

## Phase 3 - AWS Production Hardening

1. Add IAM least-privilege roles:
- EC2 role to read only required secrets and ECR pulls.

2. Centralize secrets:
- Store `DATABASE_URL`, app secrets in Secrets Manager/SSM.
- Inject at runtime, never in repo/user-data plaintext.

3. Add observability:
- CloudWatch logs/metrics/alarms.
- Uptime and error-rate alarms.

4. Add backup/recovery:
- RDS automated backups and retention.
- S3 bucket versioning if used for exports.

## Definition of Done for First Production Release

1. No critical/high findings in Terraform/network exposure.
2. CI passes tests + security scans.
3. CD deploys immutable Docker image from ECR.
4. RDS private and reachable only from app security group.
5. Secrets are managed outside repo.
6. Backend has auth + validation + safe error handling.
7. HTTPS enabled through ALB/ACM.

## Quick Start Implementation Checklist

1. Build missing files:
- `backend/Dockerfile`
- `.dockerignore`
- `docker-compose.yml`
- `.github/workflows/ci.yml`
- `.github/workflows/cd.yml`

2. Terraform hardening edits:
- `infra/main.tf`
- `infra/variables.tf`

3. Backend hardening edits:
- `backend/src/server.js`
- `backend/src/controllers/diagramController.js`
- add validation/auth middleware modules

4. Prisma alignment:
- `backend/prisma/schema.prisma`
- regenerate migrations for PostgreSQL

---

If you want, the next step is I can implement Phase 0 + Phase 1 directly in this repo in one pass, then scaffold CI/CD workflows in Phase 2.
