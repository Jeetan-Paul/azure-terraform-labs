variable "prefix" {
  description = "Short lowercase name used in resource names."
  type        = string
  default     = "tflab"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "westeurope"
}

variable "image" {
  description = "Container image to run. Must listen on port 80."
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"

  validation {
    condition     = startswith(var.image, "mcr.microsoft.com/")
    error_message = "Only images from Microsoft's registry (mcr.microsoft.com) are allowed in this lab."
  }
}
