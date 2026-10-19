# Azure Terraform Labs

Eleven hands-on projects that take Azure infrastructure from a first `terraform apply` on a laptop to a fully automated delivery pipeline: pull-request checks, tests, a production approval gate and a smoke test after every deploy.

Every resource in this repo was deployed to a real Azure subscription and torn down again through the same pipeline. Each project has a step-by-step guide (`README.md`) and a write-up of what happened, including what went wrong (`SUMMARY.md`).

## How it works

```text
 feature branch ──► pull request ──────────────────────────► merge to main ──► apply
                     │                                                          │
                     ├─ fmt and validate                    dev ─► test ─► prod (manual approval)
                     ├─ TFLint                                                   │
                     ├─ Checkov (security baseline)              smoke test: does the app answer?
                     ├─ terraform test (mocked providers)
                     └─ plan, posted as a PR comment
```

- **No secrets anywhere.** GitHub Actions signs in to Azure with OIDC (workload identity federation) as a user-assigned managed identity. There are no client secrets or keys stored in GitHub.
- **Remote state** lives in an Azure Storage account with shared keys disabled. Terraform and the pipeline use Microsoft Entra ID, with one state file per project and environment.
- **`main` is protected** by a ruleset: changes go through pull requests only, squash merges only, and three required checks must pass.
- **Pull requests only look; merges change Azure.** Every PR shows its plan as a comment, so the change can be reviewed before anything is deployed.

## Projects

| # | Project | What it covers |
|---|---------|----------------|
| 01 | [First deployment](01-first-deployment/) | `init`, `plan`, `apply`, `destroy`, providers, variables, outputs |
| 02 | [Remote state](02-remote-state/) | State in Azure Storage, Entra ID auth, locking, versioning, migrating state |
| 03 | [Git and GitHub](03-git-github/) | Branches, pull requests, `.gitignore` for Terraform |
| 04 | [GitHub Actions with OIDC](04-github-actions/) | Secretless login to Azure, plan on PR, apply on merge |
| 05 | [PR checks](05-pr-checks/) | `fmt`, `validate`, TFLint, Checkov, required checks with a ruleset |
| 06 | [Modules](06-modules/) | Writing a reusable module, `for_each` |
| 07 | [Hub-spoke network](07-hub-spoke/) | VNet peering, Azure Firewall, route tables, test VMs, `count` |
| 08 | [Environments](08-environments/) | dev/test/prod from one codebase, separate state, approval gate for prod |
| 09 | [Import](09-import/) | Adopting hand-built resources with `import` blocks, generated config, drift |
| 10 | [Verified modules and tests](10-verified-modules/) | Azure Verified Modules, the azapi provider, `terraform test` with mocks |
| 11 | [Real workload](11-container-app/) | Container Apps, Log Analytics, smoke test after deploy, shipping a new revision |

## What this gave me

I came in knowing Bicep from work. These labs were about the parts I hadn't done hands-on: Git, CI/CD pipelines and Azure networking.

- **Git and pull requests as the daily routine.** More than 30 merged pull requests, each with a reviewed plan. Branching, squash merges, and fixing a PR that the required checks blocked.
- **Pipelines I can explain line by line.** OIDC federation and why the token subject changes when a job uses an environment. Matrix jobs, job dependencies, approval gates, and tests and smoke tests as gates.
- **Networking proven with traffic, not diagrams.** Proving that peering isn't transitive, sending spoke-to-spoke traffic through Azure Firewall with route tables, and checking it with effective routes, next hop and real pings.
- **Debugging from logs.** Each `SUMMARY.md` records what broke and why. Examples: an NSG naming clash in my own module, a Checkov rule that only fired with `count = 1`, a resource provider that was skipped because of case sensitivity, and a smoke test that failed after a teardown because `terraform output` returns empty text (not an error) on an empty state.
- **Working from official documentation.** Provider 5.x syntax, logging that changed in 2026 and GitHub's newer OIDC subject format often differ from older tutorials. Each guide links the docs it relies on.

## Tools

| Tool | Version |
|------|---------|
| Terraform | 1.16 |
| azurerm provider | 5.x |
| azapi provider | 2.x (project 10) |
| GitHub Actions | `actions/checkout@v7`, `hashicorp/setup-terraform@v4` |
| Checks | TFLint 0.64 with the azurerm ruleset, Checkov 3.3 |

## Running it yourself

The guides use the names from my lab environment (storage account, managed identity, GitHub repository, tenant). Replace them with your own.

1. Install the tools:

   ```powershell
   winget install --id Hashicorp.Terraform --exact
   winget install --id GitHub.cli --exact
   ```

   Install the Azure CLI as well, and the **HashiCorp Terraform** extension in VS Code.

2. Sign in and select your subscription:

   ```powershell
   az login
   az account set --subscription "<your-subscription>"
   ```

   If your tenant has a sign-in frequency policy, the CLI session expires. When Terraform reports `token_expired` or `AADSTS70043`, run `az login` again.

3. Start with [01-first-deployment](01-first-deployment/). Project 02 creates the state storage, and project 04 creates the pipeline identity that the later projects reuse.

## Cost

The labs ran on a Visual Studio (MSDN) subscription with a monthly credit and the spending limit switched on. Most projects use only free resources (resource groups, VNets, NSGs) or stay within free grants (Container Apps, Log Analytics).

- **Tear down after each project.** Every project ends by removing its resources through a pull request.
- **Keep the spending limit on.** When the credit runs out, Azure disables the subscription for the rest of the billing period instead of charging you. Marketplace and third-party services aren't covered. ([docs](https://learn.microsoft.com/azure/cost-management-billing/manage/spending-limit))
- **Set a budget as an early warning.** Budgets only send email; they don't stop anything. With an MSDN subscription, choose the **Billing month** reset period. ([docs](https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-acm-create-budgets))
- **Watch the expensive ones.** Azure Firewall in West Europe costs €0.34 to €1.50 per hour depending on the tier, before data processing (Azure Retail Prices API, checked 24 Sep 2026). VMs, Bastion, VPN Gateway and AKS also cost money while they run.
- **Check what exists:** `az resource list -o table`.
