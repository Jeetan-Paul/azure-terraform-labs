# 09 – Import

Someone built a network by hand. You bring it under Terraform **without deleting or rebuilding anything**, using `import` blocks. Then you let the pipeline put back a change someone made in the portal.

**Time:** about 1.5 hours. **Cost:** nothing. A resource group, a virtual network, a subnet and an NSG, all free.

## The picture (explained simply)

Terraform keeps a **notebook** (the state). It only looks after things written in that notebook. Everything you built in labs 01–08 got written in automatically, because Terraform built it.

But in real jobs, a lot of Azure was **clicked together in the portal** before anyone used Terraform. Those things exist, but they're not in the notebook, so Terraform doesn't know them. If you just wrote code for them, Terraform would try to **build them again** and fail, because the name is already taken.

**Importing** = writing an existing thing into the notebook, without touching the thing itself. Like registering a house that's already built: nobody knocks it down, it just gets on the official map.

## What's new

| Idea | Where | What it does |
|------|-------|--------------|
| **`import` block** | `imports.tf` | "This Azure resource (`id`) belongs to this resource block (`to`)." Terraform adopts it during `apply`. |
| **`-generate-config-out`** | `terraform plan` flag | Terraform reads the real resource and writes a **draft** of the code for you. Experimental, and the draft needs tidying. |
| **Data source in an ID** | `imports.tf` | `data.azurerm_client_config.current.subscription_id` looks up your subscription ID at plan time, so it's never written in the public repo. |
| **"to import" in the plan** | PR comment | A new kind of line next to add, change and destroy. |
| **Drift** | step 7 | Someone changes something in the portal; the next plan shows it, and the next apply puts it back. |

### Import block vs. the old `terraform import` command

There's also a command, `terraform import <address> <id>`. It writes to the state **immediately**, on your PC, with no plan and no PR. An `import` block goes through the normal route instead: **plan → PR → review → merge → apply**. That's why teams use the block now: the import shows up in the PR for someone to check, and the pipeline does it, not your laptop.

## Steps

### 1. Build the network by hand

Play the colleague who clicked it together. Five commands:

```powershell
az login --tenant "4017b86f-a08b-45f8-949e-5982125883a1"
az account set --subscription "sub-msdn-jeetan"

az group create -n rg-tflab-09 -l westeurope
az network vnet create -g rg-tflab-09 -n vnet-tflab-09 --address-prefixes 10.90.0.0/16 `
  --subnet-name snet-app --subnet-prefixes 10.90.1.0/24
az network nsg create -g rg-tflab-09 -n nsg-tflab-09-app
az network nsg rule create -g rg-tflab-09 --nsg-name nsg-tflab-09-app -n allow-https-in `
  --priority 100 --direction Inbound --access Allow --protocol Tcp `
  --source-address-prefixes Internet --source-port-ranges "*" `
  --destination-address-prefixes "*" --destination-port-ranges 443
az network vnet subnet update -g rg-tflab-09 --vnet-name vnet-tflab-09 -n snet-app --nsg nsg-tflab-09-app
```

- `az group create`: the resource group. `-n` = name, `-l` = location.
- `az network vnet create`: the virtual network, plus its first subnet in the same command.
- `az network nsg create` and `nsg rule create`: an NSG with one rule: HTTPS (port 443) in from the internet.
- `az network vnet subnet update ... --nsg`: hang the NSG on the subnet.
- No tags anywhere, the way hand-built things often are.

Write down the NSG's **fingerprint** (`resourceGuid`). Azure gives every object a new one when it's created, so if it's the same at the end, the object was never rebuilt:

```powershell
az network nsg show -g rg-tflab-09 -n nsg-tflab-09-app --query resourceGuid -o tsv
```

### 2. Read imports.tf

Open [imports.tf](imports.tf):

- `data "azurerm_client_config" "current" {}`: a **data source** only *reads*. This one asks Azure "who am I logged in as?" and gives back your subscription ID.
- `locals { rg_id = "/subscriptions/${...}/resourceGroups/rg-tflab-09" }`: the resource group's full Azure ID, built from that lookup. The other IDs start with it.
- Each `import` block: `to` = which resource block in the code, `id` = which resource in Azure. The ID format per resource type comes from the azurerm docs (the "Import" section at the bottom of each resource page).
- The association's ID is the **subnet's** ID: the link between subnet and NSG is stored on the subnet.
- HashiCorp's docs: the `id` must be known during plan. A data source is read during plan, so this works (tested).

### 3. Let Terraform write a draft

```powershell
cd E:\Claude\projects\azure-terraform-labs\09-import
$env:ARM_USE_CLI = "true"
terraform init
terraform plan -generate-config-out="generated.tf"
```

- `$env:ARM_USE_CLI = "true"`: on your PC, Terraform logs in with your `az login`. The pipeline uses the badge instead.
- `terraform init`: connects to the state storage (key `09-import.tfstate`) and creates the lock file.
- `-generate-config-out="generated.tf"`: for every `import` block without a matching resource block, Terraform reads the real resource and writes a **draft** into `generated.tf`. The file must not exist yet; if you run it again, delete the file first.

**Expect errors.** That's the lesson of this step. You'll see the warning `Config generation is experimental`, and errors such as:
- `expected flow_timeout_in_minutes to be in the range (4 - 30), got 0`
- `Value for unconfigurable attribute ... "subnet.0.id"`
- `Missing required argument ... network_security_group_id_wo_version`

Open `generated.tf` and look at what Terraform guessed:
- **Every** attribute is there, including empty ones (`dns_servers = []`, `tags = {}`).
- Everything is hard-coded, including your **subscription ID** in the comments and IDs. That's why `.gitignore` keeps this file out of the repo.
- The VNet contains the subnet **a second time** (`subnet = [...]`), while there's also a separate `azurerm_subnet`. Two blocks managing one thing would fight each other.
- HashiCorp's docs call the output a "best guess" and "a template": a starting point, not finished code.

### 4. Write the tidy version

Make a new file `network.tf` with five resource blocks, using `generated.tf` as your cheat sheet. Try it yourself first. The rules:

- Keep only what's needed: `name`, `resource_group_name`, `location`, `address_space` / `address_prefixes`, and anything that differs from the default.
- Use **references** instead of copied text: `resource_group_name = azurerm_resource_group.lab.name`. Then Terraform knows the order, and a rename only happens in one place.
- No `subnet` inside the VNet. The subnet gets its own block.
- Write `default_outbound_access_enabled = false` on the subnet. Azure made it private (the draft shows `false`), but the provider's default is `true`, so leaving it out would mean a change.
- The NSG rule goes inside the NSG as a `security_rule { ... }` block.
- The resource names must match the `to` addresses: `azurerm_resource_group.lab`, `azurerm_virtual_network.lab`, `azurerm_subnet.app`, `azurerm_network_security_group.app`, `azurerm_subnet_network_security_group_association.app`.

<details>
<summary>The answer (open after trying)</summary>

```hcl
# The network someone built by hand in step 1, now described in code.
# imports.tf adopts each resource into these blocks.

resource "azurerm_resource_group" "lab" {
  name     = "rg-tflab-09"
  location = "westeurope"
}

resource "azurerm_virtual_network" "lab" {
  name                = "vnet-tflab-09"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = ["10.90.0.0/16"]
}

resource "azurerm_subnet" "app" {
  name                            = "snet-app"
  resource_group_name             = azurerm_resource_group.lab.name
  virtual_network_name            = azurerm_virtual_network.lab.name
  address_prefixes                = ["10.90.1.0/24"]
  default_outbound_access_enabled = false
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-tflab-09-app"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location

  security_rule {
    name                       = "allow-https-in"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "Internet"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "443"
  }
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}
```

</details>

Then delete the draft, tidy, and plan:

```powershell
Remove-Item generated.tf
terraform fmt
terraform validate
terraform plan
```

**Expect exactly:** `Plan: 5 to import, 0 to add, 0 to change, 0 to destroy.`

- **"to import"** = written into the notebook, nothing touched in Azure.
- If it says **"to change"**, your code doesn't match what's really there. The plan shows which attribute (`-` is what Azure has, `+` is what your code says). **Fix the code, not Azure**, and plan again. The goal of an import is to describe reality, not to change it.
- If it says **"to add"** or **"to destroy"**, a resource name doesn't match its `to` address.

This plan ran locally and changed nothing. The real import happens through the pipeline.

### 5. Pull request

```powershell
cd E:\Claude\projects\azure-terraform-labs
git switch -c feature/lab-09-import
git add 09-import .github/workflows/terraform-09.yml .gitignore README.md
git status
```

**Check in `git status`:** `network.tf`, `imports.tf` and `.terraform.lock.hcl` are listed. `generated.tf` is **not** (it's deleted, and `.gitignore` would block it anyway).

```powershell
git commit -m "Add lab 09 import"
git push -u origin feature/lab-09-import
gh pr create --fill --base main
gh pr checks --watch
```

The plan comment should say `Plan: 5 to import, 0 to add, 0 to change, 0 to destroy`, with `will be imported` above each resource.

The comment shows full Azure IDs, including the subscription ID. That's not new: your Actions logs from earlier labs already show it (`Creation complete ... [id=/subscriptions/...]`). A subscription ID is an address, not a key; nobody can log in with it.

### 6. Merge: the import

```powershell
gh pr merge --squash --delete-branch
git pull
git fetch --prune
```

The `apply` job's log should end with `Apply complete! Resources: 5 imported, 0 added, 0 changed, 0 destroyed.`

Check that nothing was rebuilt. The fingerprint should be the same as in step 1:

```powershell
az network nsg show -g rg-tflab-09 -n nsg-tflab-09-app --query resourceGuid -o tsv
```

The `import` blocks stay in the code. HashiCorp's docs: an import block is idempotent (running it again does nothing once the resource is in the state), and they recommend keeping it "as an historical artifact": a note of where the resource came from.

### 7. Drift: someone clicks in the portal

**First, play the colleague again.** In the portal: **nsg-tflab-09-app** > **Settings** > **Inbound security rules** > **allow-https-in** > change **Priority** from `100` to `110` > **Save**. (Or: `az network nsg rule update -g rg-tflab-09 --nsg-name nsg-tflab-09-app -n allow-https-in --priority 110`.)

The code still says `100`. That difference between code and reality is called **drift**.

**Now a normal change:** give everything tags.

```powershell
git switch -c feature/lab-09-tags
```

At the top of `network.tf`, add:

```hcl
locals {
  tags = {
    project    = "azure-terraform-labs"
    lab        = "09"
    managed_by = "terraform"
    owner      = "jeetan"
  }
}
```

And add `tags = local.tags` to the resource group, the VNet and the NSG (the subnet and the association have no tags). Then:

```powershell
terraform fmt
git diff
git add 09-import/network.tf
git commit -m "Tag the lab 09 resources"
git push -u origin feature/lab-09-tags
gh pr create --fill --base main
gh pr checks --watch
```

The plan says `Plan: 0 to add, 3 to change, 0 to destroy`, all `updated in-place`. Look at the NSG: besides the tags, it also shows

```
- priority = 110
+ priority = 100
```

Terraform noticed the portal change, and will **put it back**, because the code is the boss now. Merge, then check:

```powershell
gh pr merge --squash --delete-branch
git pull
git fetch --prune
az network nsg rule show -g rg-tflab-09 --nsg-name nsg-tflab-09-app -n allow-https-in --query priority
```

Expect `100`. In a team, that's the signal to tell people: "this is managed by Terraform now; change it in the code, not in the portal".

## Clean up

1. `git switch -c chore/lab-09-teardown`
2. Delete `network.tf` **and** `imports.tf`. Keep `main.tf` and `backend.tf`.
   - Both have to go. If you only delete `network.tf`, the plan fails with `Configuration for import target does not exist`: the import blocks point at resource blocks that are gone (tested).
3. `terraform fmt`, `git diff`, PR. The plan: **`5 to destroy`**.
4. Merge. Check: `az group exists -n rg-tflab-09` should print `false` (it can take a few minutes).

Leaving the import blocks out doesn't "un-import" anything. Once the resources are in the state, Terraform owns them, and removing their code means "delete them". (To let go of a resource **without** deleting it, Terraform has a `removed` block. Not needed here.)

## Done when

- [ ] `terraform plan` showed `5 to import, 0 to add, 0 to change, 0 to destroy`
- [ ] The apply said `5 imported`, and the NSG's `resourceGuid` didn't change
- [ ] The tags PR showed the portal change (`110 → 100`) and put it back
- [ ] You can explain why an `import` block is safer than the `terraform import` command
- [ ] You can explain why `generated.tf` isn't committed

## References

- [Import block](https://developer.hashicorp.com/terraform/language/block/import): `to`, `id`, "the ID must be known during the plan operation"
- [Import a single resource](https://developer.hashicorp.com/terraform/language/import/single-resource): import blocks are idempotent; keep them as a historical record
- [Generating configuration](https://developer.hashicorp.com/terraform/language/import/generating-configuration): experimental, "best guess", file must not exist yet
- azurerm docs, "Import" section of each resource: [resource group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group#import), [virtual network](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network#import), [subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet#import), [NSG](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group#import), [subnet–NSG association](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association#import)
- [azurerm backend](https://developer.hashicorp.com/terraform/language/backend/azurerm): `use_cli` "can also be sourced from the `ARM_USE_CLI` environment variable"
