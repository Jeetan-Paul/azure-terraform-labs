# Tests for this folder. Run them with: terraform test
# Mocked provider: no login needed, nothing gets created.

mock_provider "azurerm" {}

# The app must be reachable from the internet, over HTTPS only,
# and must be allowed to scale to zero.
run "defaults" {
  command = plan

  assert {
    condition     = azurerm_container_app.web.ingress[0].external_enabled == true
    error_message = "The app should be reachable from the internet."
  }

  assert {
    condition     = azurerm_container_app.web.ingress[0].allow_insecure_connections == false
    error_message = "Plain HTTP must be refused; HTTPS only."
  }

  assert {
    condition     = azurerm_container_app.web.template[0].min_replicas == 0
    error_message = "The app should scale to zero when nobody visits, so it costs nothing."
  }
}

# An image from Docker Hub must be refused: only Microsoft's registry is allowed.
run "image_from_docker_hub_is_refused" {
  command = plan

  variables {
    image = "docker.io/library/nginx:latest"
  }

  expect_failures = [var.image]
}
