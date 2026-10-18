# 10 – Verified modules and tests

Build a network with **Microsoft's own modules** (Azure Verified Modules) instead of your own, and protect it with **automatic tests** that run without Azure.

**Time:** about 1.5 hours. **Cost:** nothing. A resource group, a virtual network, two subnets and an NSG, all free.

## The picture (explained simply)

- **Azure Verified Modules (AVM)** are like buying flat-pack furniture from a big store instead of building it from planks yourself. In lab 06 you made your own cookie cutter (`modules/vnet`). AVM are Microsoft's cookie cutters: written to one standard, tested and maintained by Microsoft. In real jobs you often use these instead of writing everything yourself.
- **Tests** are like a smoke detector. You install it once, and from then on it warns you every time, without you having to check. A test says: "if someone opens SSH to the internet, stop". It catches the mistake **before** the plan reaches Azure.
- **Mocks** are a pretend Azure. The tests talk to a stand-in that makes up values, so they need no login, cost nothing, and take seconds.

## What's new

| Idea | Where | What it does |
|------|-------|--------------|
| **Registry module** | `network.tf`, `module "vnet"` | `source = "Azure/avm-res-network-virtualnetwork/azurerm"` downloads Microsoft's module from the Terraform Registry at `init`. |
| **Exact version pin** | `version = "0.22.3"` | Always this version, until you change it on purpose. Below 1.0, any new version may contain breaking changes. |
| **azapi provider** | `main.tf` | The AVM modules don't use azurerm. They use **azapi**, which talks to Azure's REST API directly. Your resource group still uses azurerm: one config can mix both. |
| **`enable_telemetry = false`** | each module | AVM modules send usage data to Microsoft by default ([aka.ms/avm/telemetryinfo](https://aka.ms/avm/telemetryinfo)). Switched off here. |
| **`terraform test`** | `tests/network.tftest.hcl` | Runs `run` blocks with `assert` (this must be true) and `expect_failures` (this must be refused). |
| **`mock_provider`** | test file | A pretend azurerm and azapi. No login, nothing created. |
| **Test in the pipeline** | `terraform-10.yml`, step `Test` | Every PR runs the tests before the plan. |

### Your module vs. Microsoft's

| | Your `06-modules/modules/vnet` | AVM `avm-res-network-virtualnetwork` |
|---|---|---|
| Who maintains it | You | Microsoft |
| Provider | azurerm | azapi |
| Size | about 40 lines | far more: peering, IPAM, locks, role assignments, diagnostics, ... |
| NSG per subnet | built in, always | you pass one in (`network_security_group = { id = ... }`) |
| Private subnets | you wrote `default_outbound_access_enabled = false` | default `false` |

Neither is "better". Your own module is small and you know every line. AVM covers far more, but you read its documentation instead of its code.

### Checkov and module sources

Checkov's `CKV_TF_1` wants every module to come from a Git URL with a **commit hash**, such as `git::https://github.com/...?ref=<40-character hash>`. A hash can never point to different code, so nobody can slip something new under a version you already approved. That's a supply-chain rule: trusting code you download.

This lab uses the Terraform Registry with an exact version instead: `source` plus `version`, as each module's Registry page shows under "Provision Instructions". Both modules have a documented skip in `network.tf`: `#checkov:skip=CKV_TF_1:...`. In a team with strict supply-chain rules, you'd switch to commit hashes, or copy the modules into your own repo or registry.

## Steps

### 1. Read the code

- [main.tf](main.tf): two providers, `azurerm` and `azapi`. Both log in with the same `ARM_*` variables (azapi docs: `use_oidc` "can also be sourced from the `ARM_USE_OIDC` Environment Variable").
- [network.tf](network.tf):
  - `local.security_rules`: a `for` expression turns the list `[443]` into one NSG rule per port: `allow-443-in`, priority 100. A second port would get priority 110.
  - `module "nsg"` and `module "vnet"`: Microsoft's modules. `parent_id` is where the resource goes: the resource group's ID.
  - In `subnets`, every subnet gets `network_security_group = { id = module.nsg.resource_id }`: the output of one module goes into the other.
- [variables.tf](variables.tf): two **validations**. `address_space` must be a valid CIDR, and `allowed_inbound_ports` may not contain 22.
- [tests/network.tftest.hcl](tests/network.tftest.hcl): three tests (step 3).

Open the module pages and compare with what `network.tf` uses:
- [avm-res-network-virtualnetwork](https://registry.terraform.io/modules/Azure/avm-res-network-virtualnetwork/azurerm/0.22.3): the **Inputs** tab lists `subnets` with all its options.
- [avm-res-network-networksecuritygroup](https://registry.terraform.io/modules/Azure/avm-res-network-networksecuritygroup/azurerm/0.6.0)

### 2. Download the modules

No Azure login needed for steps 2 to 4.

```powershell
cd E:\Claude\projects\azure-terraform-labs\10-verified-modules
terraform init -backend=false
```

- `-backend=false`: don't connect to the state storage. Tests don't need it.
- Watch the output: `Downloading registry.terraform.io/Azure/avm-res-network-virtualnetwork/azurerm 0.22.3 for vnet...`. The modules themselves use smaller helper modules (`avm-utl-interfaces`), which come along too.
- The providers: `azurerm`, `azapi`, plus `modtm` (telemetry), `random` and `time`, which the modules ask for.

Have a look inside `.terraform\modules\vnet\`: that's Microsoft's code, downloaded. Open `main.tf` there and find `azapi_resource "vnet"`. Don't change anything in that folder: `init` overwrites it.

### 3. Run the tests

```powershell
terraform test
```

Expect:

```
tests\network.tftest.hcl... in progress
  run "defaults"... pass
  run "ssh_from_internet_is_refused"... pass
  run "bad_address_space_is_refused"... pass
tests\network.tftest.hcl... tearing down
tests\network.tftest.hcl... pass

Success! 3 passed, 0 failed.
```

What each test does:
- **`defaults`**: plans with the default settings and checks three things with `assert`: the resource group's name, the `managed_by` tag, and that only `allow-443-in` exists.
- **`ssh_from_internet_is_refused`**: plans with `allowed_inbound_ports = [443, 22]`. `expect_failures = [var.allowed_inbound_ports]` means: this variable's validation **must** refuse it. If it's accepted, the test fails.
- **`bad_address_space_is_refused`**: the same, with `10.100.0.0/33` (a /33 doesn't exist).
- `command = plan`: stop after the plan. Without it, a test runs `apply` by default, and with real providers that creates real resources (HashiCorp's docs).
- `mock_provider "azurerm" {}` and `mock_provider "azapi" {}`: the pretend Azure. HashiCorp's docs: mocks generate fake values, so the tests run "without creating infrastructure or requiring credentials".

### 4. Write a test first, then the rule

RDP (port 3389) open to the internet is just as dangerous as SSH. Add that protection the way developers do: **test first**.

**4a. Write the test.** At the bottom of `tests/network.tftest.hcl`, add a fourth `run` block called `rdp_from_internet_is_refused`. Copy the SSH one and change what's needed.

```powershell
terraform test
```

**Expect it to fail:** `Failure! 3 passed, 1 failed`, with `Missing expected failure ... var.allowed_inbound_ports, was expected to report an error but did not`. That's correct: the rule doesn't exist yet, so 3389 is accepted. A test that has never failed has never proved it can catch anything.

**4b. Add the rule.** In `variables.tf`, extend the `condition` of `allowed_inbound_ports` so 3389 is refused too, and update the `error_message`. Then:

```powershell
terraform test
```

**Expect:** `Success! 4 passed, 0 failed.`

<details>
<summary>The answer (open after trying)</summary>

The test:

```hcl
run "rdp_from_internet_is_refused" {
  command = plan

  variables {
    allowed_inbound_ports = [443, 3389]
  }

  expect_failures = [var.allowed_inbound_ports]
}
```

The rule (`&&` means "and": both must be true):

```hcl
  validation {
    condition     = !contains(var.allowed_inbound_ports, 22) && !contains(var.allowed_inbound_ports, 3389)
    error_message = "SSH (22) and RDP (3389) may not be opened to the internet. Use Azure Bastion instead."
  }
```

</details>

Then `terraform fmt -recursive`, and check that the tests still pass.

### 5. Pull request

```powershell
cd E:\Claude\projects\azure-terraform-labs
git switch -c feature/lab-10-verified-modules
git add 10-verified-modules .github/workflows/terraform-10.yml README.md
git status
```

Check that `.terraform.lock.hcl` and `tests/network.tftest.hcl` are listed, and no `.terraform/` folder.

```powershell
git commit -m "Add lab 10 verified modules and tests"
git push -u origin feature/lab-10-verified-modules
gh pr create --fill --base main
gh pr checks --watch
```

The `plan` job now has a **Test** step before the plan. Open the job's log and find `Success! 4 passed, 0 failed.` The plan comment should say **`Plan: 6 to add`**:

- `azurerm_resource_group.lab`
- `module.nsg.azapi_resource.this` and `module.nsg.azapi_resource.security_rules["allow-443-in"]`
- `module.vnet.azapi_resource.vnet`
- `module.vnet.module.subnet["snet-app"].azapi_resource.subnet[0]` and `["snet-data"]`

Note the addresses: `module.vnet.module.subnet[...]` is a module **inside** a module.

### 6. Merge

```powershell
gh pr merge --squash --delete-branch
git pull
git fetch --prune
```

The apply should end with `Apply complete! Resources: 6 added, 0 changed, 0 destroyed.` Check:

```powershell
az network vnet subnet list -g rg-tflab-10 --vnet-name vnet-tflab-10 --query "[].{name:name, prefix:addressPrefixes[0], defaultOutbound:defaultOutboundAccess, nsg:networkSecurityGroup.id}" -o table
```

- Two subnets, `10.100.1.0/24` and `10.100.2.0/24`.
- `defaultOutbound` = `False`: private, the AVM default.
- `nsg` ends in `nsg-tflab-10` on both.

### 7. Let a test stop a bad PR (optional)

```powershell
git switch -c test/lab-10-open-ssh
```

In `variables.tf`, change the default of `allowed_inbound_ports` to `[443, 22]`. Commit, push, open a PR, and watch the `plan` job go **red** on the **Test** step. Nothing reaches Azure.

Then close the PR without merging, and throw the branch away:

```powershell
gh pr close --delete-branch
git switch main
git branch -D test/lab-10-open-ssh
```

- `gh pr close --delete-branch`: closes the PR and deletes the branch on GitHub.
- `git branch -D`: deletes the branch on your PC. Capital `-D` = also when it was never merged.

## Clean up

1. `git switch -c chore/lab-10-teardown`
2. Delete `network.tf`, `outputs.tf`, `variables.tf` and the `tests` folder. Keep `main.tf` and `backend.tf`.
   - The tests have to go too: they check resources and variables that won't exist anymore. With no test files left, `terraform test` says `Success! 0 passed, 0 failed.` and the pipeline stays green (tested).
3. `terraform fmt`, `git status`, PR. The plan: **`6 to destroy`**.
4. Merge. Check: `az group exists -n rg-tflab-10` should print `false`.

## Done when

- [ ] `terraform test` showed `4 passed`, after your RDP test first failed
- [ ] The PR's `plan` job ran the tests and planned `6 to add`
- [ ] The subnets in Azure are private and both use `nsg-tflab-10`
- [ ] You can explain what a mock provider is, and why the tests need no Azure login
- [ ] You can explain why the module versions are pinned exactly

## References

- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/): what AVM is, and the module index
- [avm-res-network-virtualnetwork 0.22.3](https://registry.terraform.io/modules/Azure/avm-res-network-virtualnetwork/azurerm/0.22.3) and [avm-res-network-networksecuritygroup 0.6.0](https://registry.terraform.io/modules/Azure/avm-res-network-networksecuritygroup/azurerm/0.6.0): inputs, outputs, resources
- [Tests](https://developer.hashicorp.com/terraform/language/tests): `run`, `command`, `assert`, `expect_failures`; tests create real infrastructure by default
- [Mocks](https://developer.hashicorp.com/terraform/language/tests/mocking): `mock_provider`; fake values; no credentials needed
- [azapi provider](https://registry.terraform.io/providers/Azure/azapi/latest/docs): `use_oidc` and `use_cli` read `ARM_USE_OIDC` and `ARM_USE_CLI`
