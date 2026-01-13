# Workload Identity Federation Demo

Authenticate to Snowflake from GitHub Actions **without storing any secrets**.

## How It Works

```
┌─────────────────────┐                      ┌─────────────────────┐
│   GitHub Actions    │  ── OIDC Token ──▶   │     Snowflake       │
│   Workflow Runner   │     (short-lived)    │   SERVICE User      │
└─────────────────────┘                      └─────────────────────┘
         │                                            │
         │ • Issuer: token.actions.githubusercontent.com
         │ • Subject: repo:iamontheinet/automated-intelligence:ref:refs/heads/main
         │ • No secrets stored anywhere!
         ▼                                            ▼
    GitHub vouches                              Snowflake validates
    for the workflow                            and grants access
```

## Why This Matters

| Old Way (Secrets) | New Way (OIDC) |
|-------------------|----------------|
| Store password in GitHub Secrets | No secrets stored |
| Credentials can leak | Nothing to leak |
| Manual rotation required | Tokens auto-expire (10 min) |
| Same creds for all workflows | Each run gets unique token |

## Setup

### 1. Create Snowflake SERVICE User (run as ACCOUNTADMIN)

```sql
-- See: workload-identity/setup.sql
CREATE OR REPLACE USER github_actions_dbt
WORKLOAD_IDENTITY = (
  TYPE = OIDC
  ISSUER = 'https://token.actions.githubusercontent.com'
  SUBJECT = 'repo:iamontheinet/automated-intelligence:ref:refs/heads/main'
)
TYPE = SERVICE
DEFAULT_ROLE = SNOWFLAKE_INTELLIGENCE_ADMIN;

GRANT ROLE SNOWFLAKE_INTELLIGENCE_ADMIN TO USER github_actions_dbt;
```

### 2. Push the workflow file

The workflow is at `.github/workflows/dbt-oidc-demo.yml`

### 3. Run the demo

1. Go to GitHub → Actions → "❄️ dbt CI (OIDC Demo)"
2. Click "Run workflow"
3. Watch the magic happen!

## 30-Second Demo Script

| Time | Action | Highlight |
|------|--------|-----------|
| 0-5s | GitHub → Settings → Secrets | **"No Snowflake credentials!"** |
| 5-10s | Actions → Run workflow | Click the button |
| 10-25s | Watch workflow execute | OIDC auth → dbt test → query |
| 25-30s | Show output | **"20K customers, $8M revenue, zero secrets!"** |

## Files

| File | Location | Purpose |
|------|----------|---------|
| `setup.sql` | `workload-identity/` | Snowflake SERVICE user setup |
| `dbt-oidc-demo.yml` | `.github/workflows/` | GitHub Actions workflow |
| `profiles.yml` | `dbt-analytics/` | Added `oidc` target |

## Supported Platforms

This demo uses GitHub Actions OIDC. The same pattern works with:

| Platform | OIDC Issuer |
|----------|-------------|
| GitHub Actions | `token.actions.githubusercontent.com` |
| AWS (EC2, Lambda) | Use `TYPE = AWS` instead |
| EKS | `oidc.eks.<region>.amazonaws.com/id/<id>` |
| AKS | `<region>.oic.prod-aks.azure.com/<tenant>/<id>` |
| GKE | `container.googleapis.com/v1/projects/<proj>/...` |

See `.snowflake/cortex/skills/workload-identity-federation/SKILL.md` for full documentation.

## Troubleshooting

**"User not found"**
- Verify the SERVICE user was created
- Check `DESCRIBE USER github_actions_dbt`

**"Invalid OIDC token"**
- Verify ISSUER matches exactly: `https://token.actions.githubusercontent.com`
- Verify SUBJECT matches: `repo:iamontheinet/automated-intelligence:ref:refs/heads/main`
- Check you're on the `main` branch

**"Role not authorized"**
- Ensure role was granted: `GRANT ROLE ... TO USER github_actions_dbt`
