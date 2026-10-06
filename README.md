# Azure Terraform Labs

Hands-on projects for learning Terraform and GitHub Actions on Azure, from a first local deployment to pipelines with approvals.

Lab environment: MSDN subscription `sub-msdn-jeetan` (€130 credit per month, spending limit on).

This repo is public. Projects 01–04 were first built in a private repo; that history is kept in a private archive.

## Roadmap

| # | Project | What you learn | Status |
|---|---------|----------------|--------|
| 01 | [First deployment](01-first-deployment/) | `init`, `plan`, `apply`, `destroy`, providers, variables, outputs | done |
| 02 | [Remote state](02-remote-state/) | State in an Azure storage account, Entra ID auth, locking, versioning, migrating state | done |
| 03 | [Git and GitHub](03-git-github/) | Repo, branches, pull requests, `.gitignore` for Terraform | done |
| 04 | [GitHub Actions with OIDC](04-github-actions/) | Login to Azure without secrets, `plan` on PR, `apply` on merge | done |
| 05 | [PR checks](05-pr-checks/) | `fmt`, `validate`, TFLint, Checkov, required checks with a ruleset | done |
| 06 | [Modules](06-modules/) | Write your own module, call it twice, `for_each` | done |
| 07 | [Hub-spoke network](07-hub-spoke/) | Peering, why it isn't transitive, Azure Firewall, route tables, test VMs, `count` | done |
| 08 | Environments | dev/test/prod with separate state and an approval gate for prod | todo |
| 09 | Import | Bring hand-built resources under Terraform with `import` blocks | todo |
| 10 | Verified modules and tests | Azure Verified Modules, `terraform test` | todo |
| 11 | Real workload | AVD host pool or Container Apps with monitoring, deployed by pipeline | todo |

Projects 01, 02, 08 and 09 cover a large part of the Terraform Associate exam.

## One-time setup

```powershell
winget install --id Hashicorp.Terraform --exact
winget install --id GitHub.cli --exact
```

Open a new terminal, then check:

```powershell
terraform version
az version
git --version
gh --version
```

In VS Code, install the **HashiCorp Terraform** extension.

Log in to Azure and select the lab subscription:

```powershell
az login
az account set --subscription "sub-msdn-jeetan"
az account show --query "{name:name, id:id}" -o table
```

Your tenant has a sign-in frequency policy, so the CLI login expires after about 9 hours. If Terraform fails with `token_expired` or `AADSTS70043`, run `az login` again.

## Cost rules

- Run `terraform destroy` at the end of every session unless the next project needs the resources.
- The spending limit is what protects you. When the credit runs out, Azure disables the subscription for the rest of the billing period and deallocates VMs, so nothing is charged. It doesn't cover Marketplace and third-party services, which are billed separately. Don't remove the spending limit. ([docs](https://learn.microsoft.com/azure/cost-management-billing/manage/spending-limit))
- Set a budget as an early warning: Portal > Subscriptions > `sub-msdn-jeetan` > Budgets > Add. Choose reset period **Billing month**, because MSDN billing periods might not match the calendar month. Enter 50 EUR and alert at 80%. Budgets only send email; they don't stop anything. ([docs](https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-acm-create-budgets))
- Don't leave expensive resources running. Azure Firewall in West Europe costs €0.34/hour (Basic), €1.07/hour (Standard) or €1.50/hour (Premium) for deployment alone, plus data processed (Azure Retail Prices API, checked 24 Sep 2026). VPN Gateway, Bastion, VMs and AKS also cost money while they run.
- Check what exists: `az resource list -o table`.
