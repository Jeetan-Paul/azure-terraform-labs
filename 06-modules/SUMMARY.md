# 06 – What I learned

## The idea, simply

A **module** is a cookie cutter. I made one (`modules/vnet/`: a virtual network, subnets, and an NSG on every subnet) and pressed it three times: `hub`, `spoke` and `spoke2`. Each call gives its own inputs; the module gives back outputs.

| Bicep | Terraform |
|-------|-----------|
| `module hub './modules/vnet.bicep' = { params: {...} }` | `module "hub" { source = "./modules/vnet" ... }` |
| `param` | `variable` |
| `output` / `hub.outputs.id` | `output` / `module.hub.id` |
| `for` loop | `for_each` |

- **Root module:** the folder Terraform runs in. Has the provider and backend.
- **Child module:** a folder that's called. No provider block, no backend; it only says which providers it needs.

## `for_each`

```hcl
resource "azurerm_subnet" "this" {
  for_each         = var.subnets   # map: name => address range
  name             = each.key
  address_prefixes = [each.value]
}
```

One resource per entry. In the plan: `module.spoke.azurerm_subnet.this["snet-app"]` = in module call `spoke`, resource `azurerm_subnet.this`, copy for key `snet-app`. Adding a key adds resources without touching the others, because `for_each` matches by key.

## What happened

| PR | Change | Plan |
|----|--------|------|
| #5 | Add the module, hub and spoke | 12 to add |
| #6 | One line: `"snet-web"` in the spoke | 3 to add (subnet, NSG, link) |
| #7 | Second spoke | 4 to add, but the **apply failed** |
| #8 | Fix NSG names in the module | 10 to add, 8 to destroy (replacements) |
| #9 | Remove everything | 19 to destroy |

## The failure, and the lesson

The module named NSGs `nsg-${each.key}`. Both spokes had a subnet `snet-app`, so both wanted an NSG `nsg-snet-app` **in the same resource group**:

```
Error: a resource with the ID ".../networkSecurityGroups/nsg-snet-app" already exists
```

- Subnet names only need to be unique **inside their network**. NSG names must be unique **in the resource group**.
- Terraform stops at the first error. The network and subnet of `spoke2` were already made; the NSG and link weren't. Half finished, not broken.
- Fix: `name = "nsg-${var.name}-${each.key}"`, so the network name is part of it.
- Because the fix changed the **module**, every caller changed: all 4 existing NSGs said `# forces replacement` on `name` (Azure can't rename an NSG), and their links were replaced too because the NSG ID changed.
- Reviewing that plan: check *why* each replacement happens, and that nothing unexpected (like a network) is being destroyed.

**Names a module creates must be unique wherever that resource type lives. Changing them later affects every caller.**

## Other things

- **Don't trust defaults.** The module sets `default_outbound_access_enabled = false` (private subnets). Microsoft makes that the default for new virtual networks, but the azurerm provider's default is `true`.
- **NetworkWatcherRG** appears by itself: Azure turns on Network Watcher in a region when the first virtual network is created there, at no charge. It isn't in Terraform's state.
- **Azure only changes after the merge.** A PR only plans. The merge is a push to `main`, which starts the `apply` job.
- **Teardown:** remove the resource and module blocks, empty the outputs and variables, keep the provider. The module folder stays for project 07.
- **The workflow is a copy** of project 04's. Reusable workflows can fix that later.
