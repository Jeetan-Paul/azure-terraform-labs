output "app_url" {
  description = "Public HTTPS address of the web app."
  value       = "https://${azurerm_container_app.web.ingress[0].fqdn}"
}
