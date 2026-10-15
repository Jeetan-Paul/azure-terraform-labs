# 09 – What I learned

## The idea, simply

- Terraform only looks after what's in its **notebook** (the state). Things built by hand aren't in it.
- **Importing** writes an existing resource into the notebook without touching it. Like registering a house that's already built.
- After the import, **the code is the boss**: a change made in the portal is undone by the next apply.

## What I did (15 Oct 2026, West Europe)

| Step | What | Result |
|------|------|--------|
| 1 | Built RG, VNet, subnet, NSG + rule by hand with `az` | NSG fingerprint `265217f9-...` |
| 3 | `terraform plan -generate-config-out="generated.tf"` | A draft, plus 5 errors in Terraform's own draft |
| 4 | Wrote the tidy `network.tf` myself | Local plan: `5 to import, 0 to add, 0 to change, 0 to destroy` |
| 5–6 | PR #20, merge | `5 imported`; fingerprint **unchanged**, so nothing was rebuilt |
| 7 | Priority 110 in the portal, then tags via PR #21 | Plan showed `priority 110 → 100` next to the tags; `3 changed`; back to 100 |
| Clean up | PR #22: deleted `network.tf` and `imports.tf` | `5 destroyed` |

## New things

- **`import` block:** `to` = the resource block in the code, `id` = the resource's Azure ID. The ID format is in the "Import" section of each azurerm resource page.
- **The association's import ID is the subnet's ID**, because Azure stores the link on the subnet.
- **A data source in the ID:** `data.azurerm_client_config.current.subscription_id`, so the subscription ID isn't written in the public repo.
- **`-generate-config-out`** writes a draft. It's experimental, and the file must not exist yet.
- **Import blocks stay** after the import. They're idempotent, and HashiCorp recommends keeping them as a record of where a resource came from.
- **Import block vs. the `terraform import` command:** the block goes through plan → PR → review → apply. The command changes the state straight away from my PC.

## Mistakes I made while writing network.tf (and what they mean)

| What I wrote | Error | Why |
|---|---|---|
| Left `generated.tf` in the folder | `resource ... already declared` | Terraform reads **every** `.tf` file in a folder as one whole |
| `access = "Allow-hhtps-in"` | `expected security_rule.0.access to be one of ["Allow" "Deny"]` | `access` is only `Allow` or `Deny`; the name goes in `name` |
| `security_rule = [{ ... }]` without the empty fields | `Incorrect attribute value type ... are required` | With `=` and brackets, **every** field is required. As a block (`security_rule { }`), only the ones you need |
| `security_rule = { ... }` | `set of object required` | The `=` makes it a value instead of a block |
| `"azurerm_resource_group.lab.name"` | (wrong name) | Quotes = literal text. Without quotes = a reference to another block |
| A leftover `"` | A screen full of `Invalid multi-line string` | One opening quote makes everything after it "text". One cause, many echoes |

## Things that surprised me

- **Terraform's own draft doesn't pass Terraform's own checks** (`flow_timeout_in_minutes = 0` while 4–30 is allowed, `subnet.0.id`, `*_wo_version`).
- **`generated.tf` contains the subscription ID**, so `.gitignore` blocks it.
- **`default_outbound_access_enabled = false` has to be written out.** Azure makes new subnets private, but the provider's default is `true`, so leaving it out means a change.
- **Drift shows up in any PR for that folder**, not only in a PR about that resource.
- **For the teardown, `imports.tf` has to go too.** Otherwise: `Configuration for import target does not exist`.

## Cost

Nothing. Resource groups, VNets, subnets and NSGs are free.
