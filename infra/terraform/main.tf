terraform {
    required_providers {
        azurerm = {
            source = "hashicorp/azurerm"
            version = "~> 4.0"
        }
    }

    required_version = ">= 1.5.0"

    backend "azurerm" {
    resource_group_name  = "plinfra-tfstate-rg"
    storage_account_name = "plinfratfstate"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
    }
}

provider "azurerm" {

    features {}
    subscription_id = var.subscription_id
}

locals {
    prefix = "${var.project_name}-${var.environment}"
    tags = {
        project = var.project_name
        environment = var.environment
        managed_by = "terraform"
    }
}

resource "azurerm_resource_group" "main" {
    name = "${local.prefix}-rg"
    location = var.location
    tags = local.tags
}


resource "azurerm_container_registry" "acr" {
    name = "${var.project_name}${var.environment}acr"
    resource_group_name = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location
    sku = "Basic"
    admin_enabled = false
    tags = local.tags
}

resource "azurerm_kubernetes_cluster" "aks" {
    name = "${var.prefix}-aks"
    resource_group_name = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location
    dns_prefix = "${var.prefix}-aks"

    default_node_pool {
        name = "default"
        node_count = var.aks_node_count
        node_size = var.aks_node_size
    }

    identity {
        type = "SystemAssigned"
    }

    network_profile {
        network_plugin = "azure"
        dns_service_ip = "10.0.0.10"
        service_cidr   = "10.0.0.0/16"
    }

    tags = local.tags
    
}

# ── Grant AKS permission to pull from ACR ──────────────────────
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}








