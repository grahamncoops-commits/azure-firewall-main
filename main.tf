provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "firewall-rg"
  location = "UK South"
}
#blank comment
resource "azurerm_virtual_network" "vnet" {
  name                = "firewall-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "firewall_subnet" {
  name                 = "AzureFirewallSubnet"   # must be this exact name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/26"]
}

resource "azurerm_public_ip" "fw_pip" {
  name                = "firewall-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "fw" {
  name                = "my-azure-firewall"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.fw_policy.id  # add this line

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.firewall_subnet.id
    public_ip_address_id = azurerm_public_ip.fw_pip.id
  }
}

# Firewall Policy
resource "azurerm_firewall_policy" "fw_policy" {
  name                = "fw-policy"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# Rule collection group (holds all your rules)
resource "azurerm_firewall_policy_rule_collection_group" "fw_rules" {
  name               = "fw-rule-collection-group"
  firewall_policy_id = azurerm_firewall_policy.fw_policy.id
  priority           = 100

  # --- NETWORK RULES ---
  # Control traffic by IP, port and protocol
  network_rule_collection {
    name     = "network-rules"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "allow-dns"
      protocols             = ["UDP"]
      source_addresses      = ["10.0.0.0/16"]
      destination_addresses = ["8.8.8.8", "8.8.4.4"]
      destination_ports     = ["53"]
    }

    rule {
      name                  = "allow-ntp"
      protocols             = ["UDP"]
      source_addresses      = ["10.0.0.0/16"]
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }
  }

  # --- APPLICATION RULES ---
  # Control traffic by website address (FQDN)
  application_rule_collection {
    name     = "application-rules"
    priority = 200
    action   = "Allow"

    rule {
      name             = "allow-microsoft"
      source_addresses = ["10.0.0.0/16"]
      protocols {
        type = "Https"
        port = 443
      }
      destination_fqdns = [
        "*.microsoft.com",
        "*.windows.com",
        "*.windowsupdate.com"
      ]
    }

    rule {
      name             = "allow-ubuntu-updates"
      source_addresses = ["10.0.0.0/16"]
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      destination_fqdns = [
        "*.ubuntu.com",
        "*.canonical.com"
      ]
    }
  }
}
