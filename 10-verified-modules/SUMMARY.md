# 10 – What I learned

## The idea, simply

- **Azure Verified Modules (AVM)** are Microsoft's ready-made modules, like flat-pack furniture instead of building from planks. In lab 06 I made my own `vnet` module; here I used Microsoft's.
- **Tests** are a smoke detector: written once, they warn every time.
- **Mocks** are a pretend Azure. The tests need no login, cost nothing and take seconds.

## What I did (18 Oct 2026, West Europe)

| Step | What | Result |
|------|------|--------|
| 2 | `terraform init -backend=false` | 2 AVM modules + 3 helper modules; 5 providers (azurerm, azapi, modtm, random, time) |
| 3 | `terraform test` | `3 passed` |
| 4a | Wrote `rdp_from_internet_is_refused` **before** the rule | `Missing expected failure`, `3 passed, 1 failed`: the test can catch something |
| 4b | Added `&& !contains(..., 3389)` to the validation | `4 passed` |
| 5–6 | PR #24, merge | Test step `4 passed` in the pipeline, plan `6 to add`, apply `6 added` |
| 7 | PR #25 with default `[443, 22]` | Red: first at `fmt` (`[443,22]` without a space), then at **Test** (`defaults` fail, 3 skipped). Closed, never merged |
| Clean up | PR #26: deleted `network.tf`, `outputs.tf`, `variables.tf` and `tests/` | `6 destroyed` |

## New things

- **Registry modules:** `source = "Azure/avm-res-network-virtualnetwork/azurerm"` plus `version = "0.22.3"`. `init` downloads them into `.terraform/modules/`.
- **Exact version pins:** below 1.0, any new version may contain breaking changes.
- **azapi:** the AVM modules use azapi (Azure's REST API) instead of azurerm. One config can mix both. azapi reads the same `ARM_USE_OIDC` / `ARM_USE_CLI` variables.
- **`enable_telemetry = false`:** AVM modules send usage data to Microsoft unless switched off.
- **Modules inside modules:** `module.vnet.module.subnet["snet-app"]`.
- **`terraform test`:** `run` blocks with `command = plan`, `assert` (must be true) and `expect_failures` (must be refused).
- **`mock_provider`:** fake values, no credentials. Only for providers declared in my own `required_providers`; a mock for `modtm` failed with `unknown provider hashicorp/modtm`.
- **Test-first:** write the test, see it fail, then write the rule. A test that never failed has never proved anything.
- **`&&`** means "and": `!contains(list, 22) && !contains(list, 3389)`.
- **Checkov `CKV_TF_1`** wants Git commit hashes for modules (supply-chain safety). Skipped with a documented reason for this lab.

## Mistakes I made (and what they taught me)

| What I did | What happened | Lesson |
|---|---|---|
| Replaced 22 with 3389 in the rule | SSH would be allowed again; the SSH test would fail | Add a check with `&&`, don't swap it |
| Set `default = [3389]` | My own rule would refuse the default | `default` is what's normally open: keep `[443]` |
| Pasted the new `error_message` inside the old one | A stray quote | Check the whole line after pasting |
| Edited after `git add` | The basket still held the old version | `git add` again after every change |
| `gh pr close --delete-branch` without a number | `number, url, or branch required` | `close` doesn't guess the PR like `merge` does |
| `[443,22]` | `fmt` failed before the tests | The cheapest check runs first |

## Your module vs. Microsoft's

My own module is about 40 lines and I know every one. AVM covers far more (peering, IPAM, locks, role assignments, diagnostics), but I read its documentation instead of its code. Its subnets are private by default.

## Cost

Nothing. Resource groups, VNets, subnets and NSGs are free.
