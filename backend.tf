terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "gcoopstfstateaccount" # must be globally unique
    container_name       = "tfstate"
    key                  = "firewall.tfstate"
  }
}