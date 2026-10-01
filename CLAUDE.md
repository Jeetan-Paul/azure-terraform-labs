# Rules for this project

## Check the docs, never assume

Every technical claim in this repo must come from official documentation or a real test. Don't write anything from memory.

This covers code, commands, argument names, defaults, versions, prices, portal paths, links, and statements about how Terraform, Azure or GitHub behave.

- **Sources that count:** HashiCorp docs and the Terraform Registry, the azurerm provider docs and its GitHub repo, Microsoft Learn, GitHub Docs, and the Azure Retail Prices API for costs. Blogs and tutorials don't count; most still use azurerm 3.x or 4.x syntax.
- **Tests that count:** `terraform fmt`, `validate` and `plan` runs, CLI output, and a real deployment.
- **Links:** open every link before adding it.
- **If you can't verify something:** leave it out, or mark it plainly as unverified in the text.
- **When you hand over work:** say what was checked, against which source, and what wasn't.
