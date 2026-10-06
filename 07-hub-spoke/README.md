# 07 – Hub-spoke networking

Build a hub network and two spoke networks with your module from project 06, connect them with **peering**, and put a small test VM in each spoke. Then prove two things:

- **07a:** with peering alone, the two spokes **can't** reach each other, even though both are connected to the hub.
- **07b:** with Azure Firewall in the hub and route tables in the spokes, they **can**, through the firewall. You'll prove it with a real ping.

**Time:** 07a about 1.5 hours, 07b about 1.5 hours. Two sessions is fine.
**Cost:** the two test VMs cost about €0.01–0.02 per hour each. **The firewall costs about €1.10 per hour** for as long as it exists, so you switch it on and off in the same session.
**Region:** Sweden Central. The cheap `B2ats_v2` VM size isn't available to this subscription in West Europe (`NotAvailableForSubscription`); there the cheapest allowed size costs about €0.09 per hour.

## The picture (explained simply)

Think of a city with a **central station** (the hub) and two **suburbs** (the spokes).

- **Peering** is a road between two networks. You build a road from suburb 1 to the station, and one from suburb 2 to the station.
- **Peering is not transitive.** A car from suburb 1 can drive to the station, but it **can't drive on through** the station to suburb 2. The station isn't a junction; each road only goes from one network to the other. To get from suburb 1 to suburb 2 you'd need a road between them, or a **traffic controller** at the station.
- **Azure Firewall** is that traffic controller. It stands in the station, receives the cars, checks them against its rules, and sends allowed cars on to the other suburb.
- **Route tables** (user-defined routes, UDRs) are the road signs in the suburbs: "for anywhere that isn't here or the station, go to the traffic controller first".

Without the signs, cars wouldn't know to go to the controller. Without the controller, the signs would point at nobody. You need both.

## What you'll build

```
                     ┌──────────────── hub: vnet-tflab-hub 10.70.0.0/16 ─────────────────┐
                     │  snet-shared 10.70.1.0/24                                          │
                     │  AzureFirewallSubnet 10.70.0.0/26  ← firewall (07b only)           │
                     └──────────────┬──────────────────────────────┬──────────────────────┘
                          peering   │                              │   peering
          ┌─────────────────────────┴──────┐          ┌────────────┴───────────────────────┐
          │ spoke1: vnet-tflab-spoke1      │          │ spoke2: vnet-tflab-spoke2          │
          │ 10.71.0.0/16                   │    ✗     │ 10.72.0.0/16                       │
          │ snet-app 10.71.1.0/24          │ no road  │ snet-app 10.72.1.0/24              │
          │ vm-spoke1  10.71.1.10          │          │ vm-spoke2  10.72.1.10              │
          └────────────────────────────────┘          └────────────────────────────────────┘
```

## Files

| File | What's in it |
|------|--------------|
| `main.tf` | Provider, resource group, three `module` calls (reusing `../06-modules/modules/vnet`), and the peerings |
| `vms.tf` | Two test VMs with fixed IP addresses. Switched on and off with `enable_test_vms` |
| `firewall.tf` | Firewall subnet, public IP, firewall policy with two rules, the firewall, and a route table per spoke. Switched on and off with `enable_firewall` |
| `variables.tf` | Region (`swedencentral`), VM size, and the two switches |
| `outputs.tf` | The VMs' IDs and the firewall's private IP |
| `backend.tf` | State key `07-hub-spoke.tfstate` |
| `ssh/tflab07.pub` | The VMs' **public** SSH key. You create it in step 1. |

Plus `.github/workflows/terraform-07.yml`. It also wakes up when something in `06-modules/modules/` changes, because this project uses that module.

## New Terraform ideas

### A module from another folder

```hcl
module "hub" {
  source = "../06-modules/modules/vnet"
```

`..` means "one folder up". The cookie cutter from project 06 is reused as is.

### `count`: a switch for a resource

```hcl
resource "azurerm_firewall" "hub" {
  count = var.enable_firewall ? 1 : 0
```

- `var.enable_firewall ? 1 : 0` means: "if `enable_firewall` is true, make **1**; otherwise make **0**". Zero copies means the resource doesn't exist.
- In the plan it's called `azurerm_firewall.hub[0]`: the first (and only) copy.
- Other resources refer to it as `azurerm_firewall.hub[0].id`.
- Changing `enable_firewall` from `false` to `true` creates the firewall; back to `false` deletes it. One word in the code switches a whole firewall on or off.

The test VMs use the same idea with `for_each`: `for_each = var.enable_test_vms ? local.test_vms : {}`. An empty map (`{}`) means no VMs.

### Peering is always a pair

A peering is one-directional, so every connection is **two** resources: `peer-hub-to-spoke1` (in the hub) and `peer-spoke1-to-hub` (in spoke 1). Both must exist before traffic flows. `allow_forwarded_traffic = true` lets traffic that the firewall forwards in from another network pass through the peering. Without it, the firewall's forwarded traffic would be dropped in 07b.

## Part 07a: peering, and why it isn't enough

### 1. Create the SSH key pair

Ubuntu VMs need an SSH key, even though we'll never log in over SSH. You make a key pair on your PC; only the **public** half goes into the repo.

```powershell
ssh-keygen -t rsa -b 4096 -f "$env:USERPROFILE\.ssh\tflab07"
```

- `ssh-keygen` makes a key pair: a **private** key (the secret, like the key to your front door) and a **public** key (like the lock, safe to give to anyone).
- `-t rsa -b 4096`: the key type and length. The azurerm docs say Azure wants the `ssh-rsa` format.
- `-f "$env:USERPROFILE\.ssh\tflab07"`: where to save it: `C:\Users\Jeetan\.ssh\tflab07` (private) and `tflab07.pub` (public). That's outside the repo, so the private key can never be committed by accident.
- It asks for a **passphrase**: press Enter twice for none. We never use the key to log in.

Copy only the public key into the repo:

```powershell
cd E:\Claude\projects\azure-terraform-labs\07-hub-spoke
New-Item -ItemType Directory -Force ssh
Copy-Item "$env:USERPROFILE\.ssh\tflab07.pub" ssh\tflab07.pub
Get-Content ssh\tflab07.pub
```

`Get-Content` shows the public key: one line starting with `ssh-rsa`. That's safe to publish.

**Why not let Terraform make the key?** Terraform's `tls_private_key` can, but HashiCorp's docs warn that the private key is then stored **unencrypted in the state file**. Generating it yourself keeps the secret off GitHub and out of the state.

### 2. Create the lock file

```powershell
terraform init -backend=false
```

You'll see `- hub in ..\06-modules\modules\vnet` and the same for `spoke1` and `spoke2`.

### 3. Pull request, plan, merge

```powershell
cd E:\Claude\projects\azure-terraform-labs
git switch -c feature/lab-07a-peering
git add 07-hub-spoke .github/workflows/terraform-07.yml README.md
git status
git commit -m "Add lab 07 hub-spoke with peering and test VMs"
git push -u origin feature/lab-07a-peering
gh pr create --fill --base main
gh pr checks --watch
```

- In `git status`, check that `07-hub-spoke/ssh/tflab07.pub` is there and that there's **no** file called just `tflab07` (without `.pub`) anywhere.
- The plan comment should say **`Plan: 21 to add`**: 3 networks with their subnets and NSGs (12), 4 peerings, 2 network cards (NICs) and 2 VMs, and the resource group.

Merge and watch the robot. VMs take a few minutes:

```powershell
gh pr merge --squash --delete-branch
git pull
git fetch --prune
gh run watch
```

### 4. Check the roads (peering state)

```powershell
az login --tenant "4017b86f-a08b-45f8-949e-5982125883a1"
az network vnet peering list -g rg-tflab-07 --vnet-name vnet-tflab-hub --query "[].{name:name, state:peeringState}" -o table
```

- `az network vnet peering list`: the peerings of one network, here the hub.
- **Expect:** `peer-hub-to-spoke1` and `peer-hub-to-spoke2`, both **`Connected`**. "Connected" means both halves of the pair exist.

### 5. Look at the road signs from spoke 1 (effective routes)

```powershell
az network nic show-effective-route-table -g rg-tflab-07 -n nic-vm-spoke1 -o table
```

- **Effective routes** are the final list of routes a network card actually uses: Azure's built-in routes plus any you added.
- This only works while the VM is **running**.
- **What to look for:**
  - `10.71.0.0/16`, next hop **VnetLocal**: its own network.
  - `10.70.0.0/16`, next hop **VNetPeering**: the hub, through the peering. (Microsoft's routing docs call it "Virtual network peering". The spelling `VNetPeering` isn't in Azure's API specification; it was confirmed by running this command on 6 Oct 2026.)
  - **No line for `10.72.0.0/16`** (spoke 2). Spoke 1 has no road there.
  - `10.0.0.0/8`, next hop **None**: Microsoft's docs say Azure adds this route for private address ranges and *drops* the traffic. Spoke 2's address `10.72.1.10` falls inside `10.0.0.0/8`.

### 6. Ask Azure where a packet would go (next hop)

```powershell
az network watcher show-next-hop -g rg-tflab-07 --vm vm-spoke1 --source-ip 10.71.1.10 --dest-ip 10.72.1.10
az network watcher show-next-hop -g rg-tflab-07 --vm vm-spoke1 --source-ip 10.71.1.10 --dest-ip 10.70.1.4
```

- **Network Watcher** is Azure's network diagnostic toolbox. It switched itself on in Sweden Central when your first network there was created (the same as `NetworkWatcherRG` in project 06).
- `show-next-hop` answers: "if this VM sends a packet from this address to that address, where does it go first?" Nothing is actually sent.
- **Expect:**
  - To spoke 2 (`10.72.1.10`): `nextHopType` **None**. The packet would be **dropped**.
  - To the hub (`10.70.1.4`): `nextHopType` **VirtualNetworkPeering**. The road to the hub works. (Not in Azure's API specification either; confirmed by running it on 6 Oct 2026. Note that this command says `VirtualNetworkPeering` while the effective routes table says `VNetPeering`, for the same thing.)
  - Both answers also say `"routeTableId": "System Route"`: the decision came from Azure's built-in routes, not from a route table you made.

**That's the core lesson of 07a:** both spokes are connected to the hub, but not to each other. Peering is not transitive.

### Between 07a and 07b

The VMs cost a little while running. If you do 07b on another day:
- **Keep them** (a few cents a day), or
- Switch them off through a PR: change the default of `enable_test_vms` to `false`. That's `2 to destroy` for the VMs and 2 for their NICs. Switch them back on (`true`) when you start 07b.

## Part 07b: the firewall as traffic controller

### 7. Switch the firewall on

```powershell
git switch -c feature/lab-07b-firewall
```

In [variables.tf](variables.tf), in `variable "enable_firewall"`, change `default = false` to:

```hcl
  default     = true
```

```powershell
terraform fmt -recursive
git diff
git add 07-hub-spoke/variables.tf
git commit -m "Switch on the hub firewall"
git push -u origin feature/lab-07b-firewall
gh pr create --fill --base main
gh pr checks --watch
```

Read the plan. **`Plan: 9 to add`**, all firewall-related:
- `azurerm_subnet.firewall[0]`: `AzureFirewallSubnet`. Azure requires exactly that name and at least a `/26`. It isn't made with the module, because the module puts an NSG on every subnet, and the firewall subnet may not have one.
- `azurerm_public_ip.firewall[0]`: the firewall's public address.
- `azurerm_firewall_policy.hub[0]` and `azurerm_firewall_policy_rule_collection_group.hub[0]`: the rules (see below).
- `azurerm_firewall.hub[0]`: the firewall itself.
- `azurerm_route_table.spoke["spoke1"]`, `["spoke2"]` and their two associations: the road signs.

**The money clock starts when you merge.** Merge, then follow the robot. Creating a firewall takes noticeably longer than a network; expect several minutes, and note how long yours took.

### 8. The firewall's rules

Open [firewall.tf](firewall.tf). The policy has two **network rule collections**:

| Collection | Allows | Why |
|------------|--------|-----|
| `allow-spoke-to-spoke` | ICMP (ping) between `10.71.0.0/16` and `10.72.0.0/16` | The test. Everything not allowed is blocked. |
| `allow-azure-management` | TCP 443 from the spokes to the `AzureCloud` service tag | Run Command needs port 443 to Azure public addresses to send its results back (Microsoft's Run Command docs). The spokes' only way out is now through the firewall. |

And the policy has `threat_intelligence_mode = "Deny"`: traffic to known malicious addresses is blocked.

The route table in each spoke has **one** route: `0.0.0.0/0` (everything) → `VirtualAppliance` at the firewall's private IP. Microsoft's routing docs explain why one route is enough: when you add a `0.0.0.0/0` route, Azure **removes** the built-in `10.0.0.0/8 → None` route. So traffic to the other spoke, which used to be dropped, now goes to the firewall. Traffic to the hub still uses the more specific peering route.

### 9. Look at the road signs again

```powershell
az network nic show-effective-route-table -g rg-tflab-07 -n nic-vm-spoke1 -o table
az network watcher show-next-hop -g rg-tflab-07 --vm vm-spoke1 --source-ip 10.71.1.10 --dest-ip 10.72.1.10
```

- **Effective routes now:** a line `0.0.0.0/0` with source **User** and next hop **VirtualAppliance** at the firewall's IP. The `10.0.0.0/8 → None` line is gone.
- **Next hop to spoke 2:** `nextHopType` **VirtualAppliance**, and `nextHopIpAddress` = the firewall's private IP. Check it against:
  ```powershell
  az network firewall show -g rg-tflab-07 -n afw-tflab-hub --query "ipConfigurations[0].privateIPAddress" -o tsv
  ```

### 10. The real test: ping from spoke 1 to spoke 2

```powershell
az vm run-command invoke -g rg-tflab-07 -n vm-spoke1 --command-id RunShellScript --scripts "ping -c 4 10.72.1.10"
```

- `az vm run-command invoke`: run a command **inside** the VM, through the Azure VM agent. No SSH, no public IP, no Bastion.
- `--command-id RunShellScript`: run a Linux shell command.
- `--scripts "ping -c 4 10.72.1.10"`: send 4 pings to the VM in spoke 2.
- It takes 20–60 seconds. Microsoft's docs say the minimum is about 20 seconds.
- **Expect** in the output (`message`): `4 packets transmitted, 4 received, 0% packet loss`.

**Why this works now:**
1. vm-spoke1 sends the ping to `10.72.1.10`. Its route table says: go to the firewall.
2. The firewall checks its rules: ICMP from spoke 1 to spoke 2, allowed.
3. The firewall forwards it into spoke 2 through the hub-spoke2 peering. `allow_forwarded_traffic` lets it in.
4. In spoke 2, the NSG allows it: the `VirtualNetwork` tag in the default rule `AllowVnetInBound` includes address prefixes from route tables (Microsoft's service tag docs), and the firewall doesn't change the source address for private ranges (Azure Firewall SNAT docs).
5. vm-spoke2 answers. The reply takes the same way back: spoke 2's route table also points to the firewall.

**Try a blocked one:** ICMP is allowed, but nothing else between the spokes is. This tries TCP port 22 (SSH) for 5 seconds:

```powershell
az vm run-command invoke -g rg-tflab-07 -n vm-spoke1 --command-id RunShellScript --scripts "timeout 5 bash -c '</dev/tcp/10.72.1.10/22' && echo OPEN || echo BLOCKED"
```

**Expect:** `BLOCKED`. The firewall dropped it, because no rule allows it. A firewall only lets through what you explicitly allow.

### 11. Switch the firewall off

Do this in the same session. The firewall costs money every hour.

```powershell
git switch main
git pull
git switch -c feature/lab-07b-firewall-off
```

Set `enable_firewall` back to `default = false`, then the usual: `fmt`, `diff`, `add`, `commit`, `push`, PR. The plan should say **`9 to destroy`**, all with `[0]` or a route table in the name. Merge.

## Clean up everything

When you're done with 07, remove it the IaC way:

1. `git switch -c chore/lab-07-teardown`
2. In `main.tf`: delete the resource group, the three `module` blocks, the `locals` block, and both peering resources. Keep `terraform` and `provider`.
3. Delete `vms.tf` and `firewall.tf` completely.
4. Empty `outputs.tf` and `variables.tf` (TFLint would flag unused variables otherwise).
5. Keep `ssh/` and `backend.tf`.
6. `fmt`, `diff`, PR. The plan shows **`21 to destroy`** with the firewall off (30 if it's still on). Check before merging.

`NetworkWatcherRG` will have a `NetworkWatcher_swedencentral` in it. It's free, and not in Terraform's state; leave it.

## Done when

- [ ] Peering shows `Connected` for both spokes
- [ ] Before the firewall: next hop from spoke 1 to spoke 2 is `None`, and the effective routes have no `10.72.0.0/16`
- [ ] After the firewall: next hop is `VirtualAppliance` at the firewall's IP
- [ ] A ping from vm-spoke1 to vm-spoke2 got 4 replies, and the TCP 22 test said `BLOCKED`
- [ ] The firewall was switched off in the same session
- [ ] You can explain why peering isn't transitive, and what the route table and the firewall each do

## References

- [Virtual network peering (Microsoft Learn)](https://learn.microsoft.com/azure/virtual-network/virtual-network-peering-overview) – service chaining in hub-spoke
- [Virtual network traffic routing (Microsoft Learn)](https://learn.microsoft.com/azure/virtual-network/virtual-networks-udr-overview) – system routes, `None`, and what a `0.0.0.0/0` UDR removes
- [Azure Firewall FAQ (Microsoft Learn)](https://learn.microsoft.com/azure/firewall/firewall-faq) – filtering traffic between spokes needs a UDR in each spoke
- [Azure Firewall SNAT private IP address ranges (Microsoft Learn)](https://learn.microsoft.com/azure/firewall/snat-private-range)
- [Service tags overview (Microsoft Learn)](https://learn.microsoft.com/azure/virtual-network/service-tags-overview) – what `VirtualNetwork` includes; service tags only as destination in Azure Firewall
- [Run Command for Linux VMs (Microsoft Learn)](https://learn.microsoft.com/azure/virtual-machines/linux/run-command) – needs outbound port 443 to Azure
- [Network Watcher FAQ (Microsoft Learn)](https://learn.microsoft.com/azure/network-watcher/frequently-asked-questions) – which features need the VM extension
- [azurerm_firewall](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall), [azurerm_virtual_network_peering](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering), [azurerm_route_table](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table) (Terraform Registry)
- [tls_private_key (Terraform Registry)](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) – the warning about private keys in state
