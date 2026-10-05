# 06 – Modules

Write a reusable building block (a **module**) for a virtual network, and use it twice: once for a hub network and once for a spoke network. Then see how one line in the code adds three resources.

**Time:** about 1.5 hours. **Cost:** nothing. Virtual networks, subnets and NSGs are free in Azure. The pipeline removes them at the end anyway.

## The picture (explained simply)

**A module is a cookie cutter.** You make the shape once. Then you press it into the dough as often as you like, and each cookie can get different toppings.

- The **module** (`modules/vnet/`) is the cutter: "a virtual network, with subnets, and an NSG (firewall) on every subnet".
- Each **module call** (`module "hub"`, `module "spoke"`) is one cookie. You give each one its own **inputs**: a name, an address range, which subnets.
- The module hands back **outputs**: the network's ID, its name, the subnet IDs. Other code can use those.

You already know this from Bicep: your parameterised templates for VMs and AVD host pools, which your colleagues reuse, work the same way.

| Bicep | Terraform |
|-------|-----------|
| `module hub './modules/vnet.bicep' = { params: {...} }` | `module "hub" { source = "./modules/vnet" ... }` |
| `param` in the module | `variable` in the module's `variables.tf` |
| `output` in the module | `output` in the module's `outputs.tf` |
| `hub.outputs.id` | `module.hub.id` |
| `for subnet in subnets: {...}` loop | `for_each = var.subnets` |

## What you'll build

```
rg-tflab-06
├── vnet-tflab-hub      10.60.0.0/16    (module "hub")
│   └── snet-shared     10.60.1.0/24  + nsg-snet-shared
└── vnet-tflab-spoke    10.61.0.0/16    (module "spoke")
    ├── snet-app        10.61.1.0/24  + nsg-snet-app
    └── snet-data       10.61.2.0/24  + nsg-snet-data
```

That's 12 resources: 1 resource group, plus 4 for the hub and 7 for the spoke. In project 07 you'll connect a hub and spokes to each other (peering).

## Files

```
06-modules/
├── main.tf          ← the root: provider, resource group, and two module calls
├── variables.tf     ← prefix, location, tags
├── outputs.tf       ← passes on some of the modules' outputs
├── backend.tf       ← state in sttfstate23461, key 06-modules.tfstate
└── modules/
    └── vnet/        ← the module (the cookie cutter)
        ├── main.tf       ← VNet, subnets, NSGs, NSG-to-subnet links
        ├── variables.tf  ← the inputs it needs
        └── outputs.tf    ← what it hands back
```

Plus `.github/workflows/terraform-06.yml`: a copy of the project 04 workflow, pointed at `06-modules/`.

- **Root module:** the folder you run Terraform in (`06-modules/`). It has the provider and the backend.
- **Child module:** a folder that's *called* by another one (`modules/vnet/`). It has **no** provider block and **no** backend: it uses whatever the root gives it. It does say which providers it *needs* (`required_providers`).

## Read the module

Open [modules/vnet/main.tf](modules/vnet/main.tf). Three new things:

### `for_each`: one resource per item in a list

```hcl
resource "azurerm_subnet" "this" {
  for_each = var.subnets          # for example { "snet-app" = "10.61.1.0/24", "snet-data" = "10.61.2.0/24" }

  name             = each.key     # "snet-app", then "snet-data"
  address_prefixes = [each.value] # "10.61.1.0/24", then "10.61.2.0/24"
  ...
}
```

- `var.subnets` is a **map**: a list of pairs, *name => value*, like a phone book.
- `for_each` makes **one subnet per pair**. Two pairs, two subnets.
- `each.key` is the name of the current pair, `each.value` its value.
- In the plan they show up as `azurerm_subnet.this["snet-app"]` and `azurerm_subnet.this["snet-data"]`. The name in `["..."]` is the key.

The NSG and the link between subnet and NSG use the same `for_each`, so every subnet automatically gets its own NSG. `azurerm_subnet.this[each.key].id` means: "the subnet with the same key as me".

### `this`

When a module has one main thing of a kind, people name it `this`: `azurerm_virtual_network.this`. Inside the module there's only one VNet, so a longer name adds nothing.

### `default_outbound_access_enabled = false`

This makes every subnet **private**: no automatic internet access. Microsoft's docs say new virtual networks get private subnets by default for API versions released after 31 March 2026, and the portal already works that way. But the azurerm provider's own default for this setting is `true`. So the module writes it down explicitly instead of trusting a default. If a VM in such a subnet needs the internet later, you add an explicit way out, such as a NAT gateway or a firewall.

## Read the root

Open [main.tf](main.tf). Each module call:

```hcl
module "spoke" {
  source = "./modules/vnet"     # where the cookie cutter is: a folder, relative to this one

  name          = "vnet-${var.prefix}-spoke"
  address_space = ["10.61.0.0/16"]
  subnets = {
    "snet-app"  = "10.61.1.0/24"
    "snet-data" = "10.61.2.0/24"
  }
  ...
}
```

- `module "spoke"`: this cookie's name. In the plan, everything it makes starts with `module.spoke.`.
- `source`: where the module lives. Here a local folder. Later (project 10) it'll be a module from the internet.
- The other lines are the **inputs**: one for every `variable` in the module's `variables.tf`. Leave out one that has no `default`, and `terraform validate` stops you.

[outputs.tf](outputs.tf) reads the module's outputs with `module.hub.id`, `module.spoke.subnet_ids`.

## Steps

### 1. Create the lock file

```powershell
cd E:\Claude\projects\azure-terraform-labs\06-modules
terraform init -backend=false
```

- Same as project 04: download the providers without connecting to the state storage.
- New this time: it also prints `Initializing modules...` and `- hub in modules\vnet`, `- spoke in modules\vnet`. Terraform registers the module calls.
- Creates `.terraform.lock.hcl` for this folder.

### 2. Open a pull request and read the plan

```powershell
cd E:\Claude\projects\azure-terraform-labs
git switch -c feature/lab-06-modules
git status
git add 06-modules .github/workflows/terraform-06.yml README.md
git status
git commit -m "Add lab 06 vnet module"
git push -u origin feature/lab-06-modules
gh pr create --fill --base main
gh pr checks --watch
```

- The first `git status` shows what's new; the second checks the box before you commit. There should be no `.terraform/` folder.
- `gh pr checks --watch` shows **four** checks: the three inspectors and `plan` from the new `terraform-06` workflow.

Read the plan comment (`gh pr view --web`). It should end with `Plan: 12 to add, 0 to change, 0 to destroy.` Look at the names:

```
# module.spoke.azurerm_subnet.this["snet-app"] will be created
```

Read it from left to right: in the module call **spoke**, the resource **azurerm_subnet.this**, the copy for key **snet-app**.

### 3. Merge and let the robot build it

```powershell
gh pr merge --squash --delete-branch
git pull
git fetch --prune
gh run list --workflow terraform-06.yml --limit 1
gh run watch
```

Check in Azure:

```powershell
az network vnet list --resource-group rg-tflab-06 --query "[].{name:name, space:addressSpace.addressPrefixes[0], subnets:length(subnets)}" -o table
```

- `az network vnet list`: all virtual networks in that resource group.
- `--query`: show only the name, the first address range, and how many subnets each has. Expect the hub with 1 and the spoke with 2.

(You'll need `az login` for this check. The pipeline itself doesn't need your login.)

### 4. Add a subnet with one line

```powershell
git switch -c feature/lab-06-web-subnet
```

In [main.tf](main.tf), in `module "spoke"`, add one line to `subnets`:

```hcl
  subnets = {
    "snet-app"  = "10.61.1.0/24"
    "snet-data" = "10.61.2.0/24"
    "snet-web"  = "10.61.3.0/24"
  }
```

```powershell
terraform fmt -recursive
git diff
git add 06-modules/main.tf
git commit -m "Add web subnet to the spoke"
git push -u origin feature/lab-06-web-subnet
gh pr create --fill --base main
gh pr checks --watch
```

The plan should say **`3 to add`**: `snet-web`, `nsg-snet-web`, and the link between them. One line in the code, three resources in Azure, all following the same pattern. **That's why you make modules.** Merge it the usual way.

### 5. Optional: a second spoke

Copy the whole `module "spoke"` block, rename it to `module "spoke2"`, and give it its own values: `name = "vnet-${var.prefix}-spoke2"`, `address_space = ["10.62.0.0/16"]`, and one subnet `"snet-app" = "10.62.1.0/24"`. The plan shows `4 to add`. The module didn't change at all; you just pressed the cutter once more.

(Network address ranges must not overlap if you ever want to connect the networks. That's why every network here has its own `10.6x.0.0/16`.)

### 6. Clean up, the IaC way

Same as project 04: remove the code, and the pipeline removes the resources.

1. `git switch -c chore/lab-06-teardown`
2. In `main.tf`: delete the `azurerm_resource_group` block and all `module` blocks. Keep the `terraform` and `provider` blocks.
3. Empty `outputs.tf` (its outputs point at the modules you just removed).
4. Delete `variables.tf` too. Without the resource group and the modules, `prefix`, `location` and `tags` are unused, and TFLint (a required check) would block the PR, just like the leftovers it found in project 04.
5. `terraform fmt -recursive`, `git diff`, commit, push, PR.
6. **Read the plan:** everything you made should say `will be destroyed`. That's 15 (or 19 with `spoke2`). Check that number before you merge.
7. Merge. Afterwards: `az group list --query "[].name" -o tsv` should no longer show `rg-tflab-06`.

The module folder `modules/vnet/` stays in the repo. You'll reuse it in project 07.

## Done when

- [ ] You can explain the difference between a root module and a child module
- [ ] A plan comment showed `module.hub...` and `module.spoke...` resources, 12 to add
- [ ] Adding one line to `subnets` gave 3 to add
- [ ] You can explain `for_each`, `each.key` and `each.value`
- [ ] Everything was removed through a PR, and `rg-tflab-06` is gone

## Good to know

- **The workflow is a copy.** `terraform-06.yml` is `terraform-04.yml` with a different folder. Copies drift apart over time. GitHub has *reusable workflows* to fix that; something for later.
- **A module change affects every caller.** If you change the module, both `hub` and `spoke` change. That's the power and the risk. In project 10 you'll see how published modules use version numbers so that callers choose when to upgrade.

## References

- [Modules (HashiCorp)](https://developer.hashicorp.com/terraform/language/modules)
- [The for_each meta-argument (HashiCorp)](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each)
- [azurerm_subnet (Terraform Registry)](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet), including `default_outbound_access_enabled`
- [Default outbound access in Azure (Microsoft Learn)](https://learn.microsoft.com/azure/virtual-network/ip-services/default-outbound-access)
