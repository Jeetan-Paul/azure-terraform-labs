# 05 – PR checks

Give the robot three inspectors that look at every pull request, and make GitHub refuse to merge until all three say OK.

**Time:** about 1.5 hours. **Cost:** nothing. This project doesn't deploy anything to Azure; the checks only read the code. Workflow runs are free in public repos.

## The picture (explained simply)

Think of a building inspection. Before a building may open, inspectors check it. Each inspector checks something different, and **all** of them must sign off.

| Inspector (check) | What it looks at | Example of what it catches |
|-------------------|------------------|----------------------------|
| **fmt-validate** | Tidiness and spelling | Messy indentation (`terraform fmt`), and code Terraform can't understand (`terraform validate`) |
| **tflint** | Mistakes and bad habits | A variable you declared but never use, an Azure VM size that doesn't exist |
| **checkov** | Security | A firewall rule that opens remote desktop (RDP) to the whole internet |

The **ruleset** is the rule at the door: "nothing gets into `main` without a pull request, and only when all three inspectors said OK".

**Why three tools?** `terraform validate` only checks that the code is *valid*. Valid code can still be messy, wasteful, or unsafe. You'll see that in step 4: validate says `Success!` while the other two say no.

## Words you'll see

| Word | Meaning |
|------|---------|
| **Linter** | A tool that reads code and points out mistakes and bad habits, without running it. TFLint is a linter for Terraform. |
| **Security scanner** | A tool that reads IaC and compares it with a list of security rules. Checkov is one. Each rule has an ID like `CKV_AZURE_9`. |
| **Status check** | A ✓ or ✗ that a robot job puts on a pull request. Each job in a workflow becomes one status check, named after the job. |
| **Required check** | A status check that must be ✓ before GitHub allows a merge. |
| **Ruleset** | A set of rules for a branch, like "PR required" and "these checks required". |
| **Baseline** | A list of known, accepted findings. The scanner only complains about findings *not* on the list. |

## What's new in the repo

| File | What it is |
|------|------------|
| `.github/workflows/checks.yml` | The robot's instructions for the three inspectors. Runs on **every** PR to `main`. |
| `.tflint.hcl` | TFLint's settings: which rule sets to use, and one rule switched off (see below). |
| `.checkov.baseline` | Checkov's list of 20 known findings in labs 01 and 02. |
| `.github/rulesets/main.json` | The rules for `main`, written as a file (rules as code). You send it to GitHub in step 3. |
| `05-pr-checks/` | Practice code: a small network that passes all checks. You'll break it on purpose in step 4. |
| `04-github-actions/variables.tf` | **Deleted.** TFLint found its three variables unused since the teardown in project 04. |

### Why there's no `paths:` filter in `checks.yml`

The project 04 workflow only runs when something in `04-github-actions/` changes. That doesn't work for **required** checks. GitHub's docs say: if a workflow is skipped because of a path filter, its checks stay "Pending" forever, and a pull request that requires them can't be merged. So the inspectors run on every PR, even one that only changes a README.

### Why one TFLint rule is switched off

TFLint's Azure plugin warns when a storage account has no `prevent_destroy` (a setting that stops Terraform from ever deleting it). That's good advice for real data. But lab resources **must** be deletable at the end of each project, so `.tflint.hcl` switches that rule off, with a comment explaining why. Switching a rule off is fine; doing it *silently* isn't. Always write down why.

### Why there's a baseline for Checkov

Checkov finds 20 problems in the storage accounts of labs 01 and 02 (10 checks × 2 accounts). Examples: no private endpoint, no soft delete, shared keys (access keys) still on.

Those labs are finished and not deployed. Fixing all 20 isn't sensible, and some fixes cost money (private endpoints, customer-managed keys). Teams handle this with a **baseline**: write down the existing findings once, and only fail on **new** ones. The old problems are visible in the file; new code can't add more.

Two things learned while setting this up:
- **Scanners can be wrong.** Checkov says blob public access isn't blocked in 01 and 02. But since azurerm 5.0, `allow_nested_items_to_be_public` defaults to `false`, so it *is* blocked. Checkov doesn't know the new default.
- **The baseline matches by name, not by file.** Checkov's source code compares only the resource name and check ID, not the file path. So *any* `azurerm_storage_account.lab` in *any* folder would be let through for those 20 checks. That's why the practice code in `05-pr-checks/` uses other names (`checks`, `workload`).

## Steps

### 1. Look at the new files

Open them in VS Code. Read the comments in `checks.yml` and `.tflint.hcl`. In `checks.yml`, notice:
- `on: pull_request` with no `paths:`.
- `permissions: contents: read`: these inspectors only read. They don't need Azure, so no badge (`id-token`) and no Azure variables.
- Three jobs, `fmt-validate`, `tflint` and `checkov`. Those names become the status check names.

### 2. Add the inspectors through a pull request

```powershell
cd E:\Claude\projects\azure-terraform-labs
git switch -c feature/lab-05-checks
git add .github .tflint.hcl .checkov.baseline 05-pr-checks 04-github-actions/variables.tf README.md
git status
git commit -m "Add lab 05 PR checks"
git push -u origin feature/lab-05-checks
gh pr create --fill --base main
gh pr checks --watch
```

- `git add 04-github-actions/variables.tf` for a file that's deleted: this records the **deletion** in the save. `git status` shows it as `deleted:`.
- `gh pr checks --watch`: you'll see **four** checks this time: the three new inspectors, plus `plan` from project 04 (because a file in `04-github-actions/` changed). All four should turn ✓.
- The `plan` comment should say `No changes`: deleting unused variables changes nothing in Azure.

Merge when everything is green:

```powershell
gh pr merge --squash --delete-branch
git pull
git fetch --prune
```

### 3. Turn on the rules for `main` (the ruleset)

```powershell
gh api --method POST repos/Jeetan-Paul/azure-terraform-labs/rulesets --input .github/rulesets/main.json
```

- `gh api`: send a request straight to GitHub's API (the programmable interface behind the website).
- `--method POST`: create something new.
- `repos/Jeetan-Paul/azure-terraform-labs/rulesets`: what to create: a ruleset in your repo.
- `--input .github/rulesets/main.json`: the contents, from the file.

What the rules in `main.json` say:

| Rule | Meaning |
|------|---------|
| `"enforcement": "active"` | The rules are on (not just a test). |
| `"include": ["~DEFAULT_BRANCH"]` | They apply to the default branch, `main`. |
| `pull_request` | Nothing reaches `main` except through a PR. `required_approving_review_count: 0` because you work alone and can't approve your own PR. `allowed_merge_methods: ["squash"]`: only squash merges, the way you've always worked. |
| `required_status_checks` | `fmt-validate`, `tflint` and `checkov` must be ✓. `strict...: false`: the branch doesn't have to be fully up to date with `main` first. |
| `non_fast_forward` | Nobody can overwrite `main`'s history (`git push --force`). |
| `deletion` | Nobody can delete `main`. |

There's no bypass list, so the rules also apply to **you**, the owner. That's on purpose.

Check that it's active:

```powershell
gh api repos/Jeetan-Paul/azure-terraform-labs/rulesets --jq '.[] | {name, enforcement}'
```

You can also see it on GitHub: repo **Settings**, then in the left sidebar under **Code, planning, and automation**, click **Rulesets** > **protect-main**.

**Why a file?** The same idea as IaC: the rules are written down, reviewed in Git, and can be recreated exactly. Clicking them together in Settings works too, but leaves no record.

### 4. Break it on purpose

Make a pull request with three mistakes, one for each inspector.

```powershell
git switch -c test/lab-05-bad-change
```

Add this to the **end** of `05-pr-checks/main.tf`. It opens remote desktop (RDP, port 3389) to the whole internet (`"*"`):

```hcl

resource "azurerm_network_security_rule" "rdp" {
  name                        = "allow-rdp"
  resource_group_name         = azurerm_resource_group.checks.name
  network_security_group_name = azurerm_network_security_group.workload.name
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
}
```

Add this to the **end** of `05-pr-checks/variables.tf`. Note `type = string` is badly aligned on purpose, and the variable isn't used anywhere:

```hcl

variable "admin_ip" {
  description = "My public IP address, for remote access."
  type = string
  default     = "203.0.113.10/32"
}
```

(`203.0.113.10` is an address reserved for documentation examples, not a real one.)

Save, then send it:

```powershell
git add 05-pr-checks
git commit -m "Allow RDP to the workload subnet"
git push -u origin test/lab-05-bad-change
gh pr create --fill --base main
gh pr checks --watch
```

**What you should see:** all three inspectors ✗ red.
- **fmt-validate**: `terraform fmt -check` lists `05-pr-checks/variables.tf` and shows the diff (the fix it wants). The job stops there, before `validate`.
- **tflint**: `variable "admin_ip" is declared but not used (terraform_unused_declarations)`.
- **checkov**: `CKV_AZURE_9: "Ensure that RDP access is restricted from the internet"`.

Read the failures yourself:

```powershell
gh run list --workflow checks.yml --limit 1
gh run view --log-failed
```

- `--log-failed`: show only the output of the steps that failed. Pick the newest run if it asks.

**Try to merge anyway:**

```powershell
gh pr merge --squash
```

GitHub should refuse, because the required checks aren't passing. Also look at the PR page in the browser (`gh pr view --web`): near the merge button it shows that merging is blocked and which required checks failed. **This is the whole point of project 05.**

### 5. Fix it

Fix all three in one go:

1. **Tidiness:** let Terraform fix the layout:
   ```powershell
   terraform fmt -recursive
   ```
   `-recursive` = all folders. It prints the files it changed: `05-pr-checks\variables.tf`.
2. **Security and the unused variable:** in `05-pr-checks/main.tf`, change
   ```hcl
   source_address_prefix       = "*"
   ```
   to
   ```hcl
   source_address_prefix       = var.admin_ip
   ```
   Now RDP is only allowed from one address (yours), and `admin_ip` is used. One line fixes two findings.

```powershell
git diff
git add 05-pr-checks
git commit -m "Restrict RDP to my IP address"
git push
gh pr checks --watch
```

- Plain `git push` is enough: `-u` in step 4 already linked this branch to GitHub.
- A new push to the PR's branch makes the inspectors run again automatically: by default, `pull_request` workflows run when a PR is opened, reopened, or its branch is updated (`synchronize`). All three should now be ✓.

Merge:

```powershell
gh pr merge --squash --delete-branch
git pull
git fetch --prune
```

### 6. Get into the habit: check before you push

The inspectors are a safety net, but it's faster to catch things yourself. Before every commit:

```powershell
terraform fmt -recursive
```

That alone prevents the most common red ✗. (You can also install TFLint and Checkov on your PC to run the same checks locally; that's optional.)

## Done when

- [ ] A PR showed four green checks, and you merged it
- [ ] `gh api .../rulesets` shows `protect-main` with `"enforcement": "active"`
- [ ] A PR with the RDP rule got three red checks, and GitHub refused to merge it
- [ ] After the fix, all three turned green and the PR merged
- [ ] You can explain why `validate` passed while the code was unsafe

## References

- [About rulesets (GitHub Docs)](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets) – available for public repos on GitHub Free
- [Create a repository ruleset (GitHub REST API)](https://docs.github.com/en/rest/repos/rules#create-a-repository-ruleset)
- [Troubleshooting required status checks (GitHub Docs)](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks) – why path filters and required checks don't mix
- [TFLint](https://github.com/terraform-linters/tflint) and its [config docs](https://github.com/terraform-linters/tflint/blob/master/docs/user-guide/config.md) – `--recursive` with an absolute `--config` path
- [TFLint Azure ruleset](https://github.com/terraform-linters/tflint-ruleset-azurerm)
- [setup-tflint action](https://github.com/terraform-linters/setup-tflint) – `GITHUB_TOKEN` for `tflint --init`
- [Checkov](https://www.checkov.io/) – `--baseline` and `--create-baseline`
- [azurerm 5.0 upgrade guide](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/5.0-upgrade-guide) – `allow_nested_items_to_be_public` now defaults to `false`
