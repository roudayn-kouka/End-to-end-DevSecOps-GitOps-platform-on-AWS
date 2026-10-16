# Runbook: deploy, operate, destroy

Every command runs from the repository root inside the dev container
(**VS Code → "Reopen in Container"**). On Windows this avoids installing Ansible, which only runs on Linux and macOS.

## 0. Prerequisites

| What | Why |
|---|---|
| AWS account + `aws configure` (or `aws sso login`) | Terraform, SSM, Ansible inventory |
| Docker Hub account + access token | Image registry |
| GitHub repository named `skyforge` (public is simplest) + fine-grained token with *Contents: read & write* | Jenkins checkout and GitOps write-back |
| Optional: a Route53 public hosted zone | HTTPS with ACM |
| Optional: Slack incoming webhook | Alert notifications |

## 1. Personalize the repository

```bash
make init GITHUB_USER=<you> DOCKERHUB_USER=<you>
cp terraform/terraform.tfvars.example terraform/terraform.tfvars        # set admin_cidrs!
cp ansible/inventory/group_vars/all/vault.yml.example ansible/inventory/group_vars/all/vault.yml
# fill in the tokens, then encrypt the file
ansible-vault encrypt ansible/inventory/group_vars/all/vault.yml
git add -A && git commit -m "chore: personalize" && git push
```

## 2. Infrastructure (≈ 5 min)

```bash
make bootstrap   # once: S3 state bucket + backend.hcl + terraform init
make plan
make infra
```

## 3. Configuration (≈ 15 min)

```bash
make deps        # Ansible collections
make configure   # Jenkins controller + agent, kubeadm cluster, Calico, ArgoCD
```

ArgoCD then installs every add-on from `argocd/apps/` by itself.

## 4. Secrets

```bash
make kubeconfig
make tunnel                         # terminal 1, keep it open
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/... make seal-secrets   # terminal 2
git add helm/skyforge/secrets-*.yaml argocd/platform/monitoring-secrets
git commit -m "chore: seal secrets" && git push
```

## 5. First delivery

Open `make urls` → Jenkins and log in as `admin` with the vault password. The `skyforge` job
polls Git every 2 minutes. You can also click **Build Now**. When the build succeeds:

- the `skyforge-dev` ArgoCD app syncs the new tag (`make argocd-ui` → https://localhost:8443, password: `make argocd-password`)
- dev is served on host `dev.<domain>` (or `curl -H 'Host: dev.skyforge.local' http://<alb-dns>`)
- approve **Promote to prod** in Jenkins, and the app URL from `make urls` serves the new version

## Day-2 operations

| Task | How |
|---|---|
| Roll back | `git revert <deploy commit>` and push. ArgoCD restores the previous tag |
| Grafana | `make grafana-ui` → http://localhost:3000 (password printed by `make seal-secrets`) |
| Shell on a node | `aws ssm start-session --target <instance-id>` (`terraform output instance_ids`) |
| Rotate the DB password | `FORCE=true ENVS=prod make seal-secrets`, commit, then restart PostgreSQL (data is kept, so also run `ALTER USER`) |
| Upgrade a tool version | Change it in `ansible/inventory/group_vars/all/main.yml`, `argocd/apps/*.yaml` or `toolImages.groovy`, then open a PR |

## Troubleshooting

| Symptom | Check |
|---|---|
| Ansible cannot connect | `session-manager-plugin` is installed. `aws ssm describe-instance-information` lists the 4 nodes. `SSM_BUCKET` is exported (`make configure` does it) |
| Jenkins agent offline | Jenkins → Nodes → agent-1 → Log. The agent SG allows 22 from the jenkins SG |
| Pods `CreateContainerConfigError` | The secret `skyforge-db` is missing: run step 4 |
| ALB target unhealthy | `kubectl -n traefik get pods`. The prod ingress (catch-all) must serve `/healthz` |
| ArgoCD app `OutOfSync` on CRDs | The app uses `ServerSideApply=true`. Click *Sync* once after the first install |

## 6. Destroy

```bash
make destroy     # keeps only the S3 state bucket (prevent_destroy)
```

Expected cost while running (us-east-1, on-demand): about **$7 per day** (≈ $0.28/hour): 3 × t3.medium, 1 × t3.large, NAT gateway, ALB.
Destroy the stack when you are not using it. The AWS Budget alert emails you at 80 % of `monthly_budget_usd`.
