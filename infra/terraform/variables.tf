variable "subscription_id" {
    description = "Azure subscription ID"
    type = string
}

variable "location" {
    description = "Azure region"
    type = string
    default = "australiaeast"
}

variable "environment" {
    description = "Environment name: dev, staging, or prod"
    type = string
    validation {
        condition = contains(["dev", "staging", "prod"], var.environment)
        error_message = "Environment must be dev, staging or prod"
    }
}

variable "project_name" {
    description = "Project name prefix"
  type        = string
  default     = "plinfra"
}

variable "aks_node_count" {
  description = "Number of AKS nodes"
  type        = number
  default     = 1
}

variable "aks_node_size" {
  description = "AKS node VM size"
  type        = string
  default     = "Standard_D2s_v3"
}