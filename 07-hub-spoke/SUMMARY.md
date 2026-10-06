# 07 – What I learned

## The idea, simply

- **Hub** = central station, **spokes** = suburbs, **peering** = a road between two networks.
- **Peering is not transitive.** Spoke 1 → hub and spoke 2 → hub doesn't mean spoke 1 → spoke 2.
- **Azure Firewall** in the hub = the traffic controller. **Route tables** in the spokes = the road signs pointing to it. You need both.
- **Default deny:** the firewall only lets through what a rule allows.

## What I proved (6 Oct 2026, Sweden Central)

| Test | 07a: peering only | 07b: firewall + route tables |
|------|-------------------|------------------------------|
| Peering state | `Connected` (both pairs) | |
| Effective routes, spoke 1 | `10.70.0.0/16 VNetPeering`, no `10.72...`, `10.0.0.0/8 None` | `0.0.0.0/0` **User → VirtualAppliance 10.70.0.4**; built-in `0.0.0.0/0 Internet` **Invalid**; **all** `None` routes gone |
| Next hop spoke 1 → spoke 2 | `None` (System Route) | `VirtualAppliance` 10.70.0.4 (route table `rt-spoke1`) |
| Next hop spoke 1 → hub | `VirtualNetworkPeering` | |
| Ping spoke 1 → spoke 2 | (Run Command can't report: no way out) | **4 sent, 4 received, 0% loss**, `ttl=63` |
| TCP 22 spoke 1 → spoke 2 | | **BLOCKED** (no rule) |

## Why the ping works

1. Route table in spoke 1: `0.0.0.0/0` → firewall. Microsoft's routing docs: adding a `0.0.0.0/0` route removes the built-in `10.0.0.0/8 → None`, so traffic to spoke 2 now goes to the firewall instead of being dropped.
2. Firewall rule `ping-between-spokes` allows ICMP between `10.71.0.0/16` and `10.72.0.0/16`.
3. `allow_forwarded_traffic = true` on the peerings lets the firewall's forwarded traffic in.
4. Spoke 2's NSG allows it: `AllowVnetInBound` uses the `VirtualNetwork` tag, which includes route-table prefixes, and the firewall doesn't SNAT private ranges, so the source stays `10.71.1.10`.
5. `ttl=63`: one hop between the VMs, which fits the firewall. A strong indication, not documented proof.

Run Command needs outbound port 443 to Azure to send results back. In private subnets it can't, until the firewall rule `vm-agent-to-azure` opened that path.

## New Terraform

- **`count` as a switch:** `count = var.enable_firewall ? 1 : 0`. In the plan: `azurerm_firewall.hub[0]`. Changing one default from `false` to `true` created 9 resources; back to `false` removed them.
- **`for_each` with an empty map** as a switch: `var.enable_test_vms ? local.test_vms : {}`.
- **A module from another folder:** `source = "../06-modules/modules/vnet"`. The 07 workflow also triggers on `06-modules/modules/**`.
- **Order comes from references.** Build: policy → rules → firewall → route tables (they need the firewall's IP) → associations. Teardown: the exact reverse.
- **`depends_on`** for a dependency Terraform can't see: the firewall waits for its rules.

## Things that surprised me

- **West Europe doesn't offer the cheap B-series VMs to this subscription** (`NotAvailableForSubscription`). Sweden Central does: B2ats_v2 at about €0.01–0.02/hour instead of about €0.09 for the cheapest size allowed in West Europe.
- **The same road has two names:** effective routes say `VNetPeering`, `show-next-hop` says `VirtualNetworkPeering`. Neither is in Azure's API specification.
- **Checkov looks at `count`.** With the firewall off, the firewall-only check `CKV_AZURE_216` didn't fail; with it on, it did. **Test both positions of a switch.**
- **`CKV_AZURE_216`** wants threat intel Deny on the firewall resource. That's for classic-rules firewalls; with a firewall policy, the setting lives in the policy (Microsoft docs). Documented as a skip with the reason.
- **`az network firewall show` needs a CLI extension.** `az resource show --resource-type Microsoft.Network/azureFirewalls --api-version 2026-03-01` works without one.
- **Timings:** firewall creation 6 min 30 s, deletion 8 min 9 s. Everything else took seconds.
- **The firewall's private IP is `10.70.0.4`:** Azure reserves the first four addresses in every subnet.
- **The SSH key:** made with `ssh-keygen` (after creating `~\.ssh`, which didn't exist yet); only the public key is in the repo. Terraform's `tls_private_key` would have stored the private key unencrypted in state.

## Cost

Two B2ats_v2 VMs for a few hours, and the firewall for about an hour (about €1.10/hour plus a capacity-unit charge).
