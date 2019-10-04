terraform {
  required_version = ">= 0.12, < 0.13"
}

provider "azurerm" {
  version = "~> 1.34.0"
}

# Hub RG
resource "azurerm_resource_group" "hub-rg" {
  name     = "CS-hub-rg"
  location = "${var.location}"
}

# Setup a shared NSG used across all RGs
resource "azurerm_network_security_group" "basic-nsg" {
  name                = "${azurerm_resource_group.hub-rg.name}-mgmt-nsg"
  location            = "${azurerm_resource_group.hub-rg.location}"
  resource_group_name = "${azurerm_resource_group.hub-rg.name}"

  security_rule {
    name                       = "allow-ssh"
    description                = "Allow SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "hub-vnet" {
  name                = "hub-vnet"
  resource_group_name = "${azurerm_resource_group.hub-rg.name}"
  location            = "${azurerm_resource_group.hub-rg.location}"
  address_space       = ["10.0.0.0/24"]
}
resource "azurerm_subnet" "hubsubnet1" {
  name                 = "hub-subnet1"
  resource_group_name  = "${azurerm_resource_group.hub-rg.name}"
  virtual_network_name = "${azurerm_virtual_network.hub-vnet.name}"
  address_prefix       = "10.0.0.0/24"
}

resource "azurerm_network_interface" "hub-nic" {
  name                      = "vm-nic"
  location                  = "${azurerm_resource_group.hub-rg.location}"
  resource_group_name       = "${azurerm_resource_group.hub-rg.name}"
  network_security_group_id = "${azurerm_network_security_group.basic-nsg.id}"
  enable_ip_forwarding      = true

  ip_configuration {
    name                          = "primary"
    subnet_id                     = "${azurerm_subnet.hubsubnet1.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.hub-pip.id}"
  }
}

resource "azurerm_virtual_machine" "hub-vm" {
  name                          = "hub-vm"
  location                      = "${azurerm_resource_group.hub-rg.location}"
  resource_group_name           = "${azurerm_resource_group.hub-rg.name}"
  primary_network_interface_id  = "${azurerm_network_interface.hub-nic.id}"
  network_interface_ids         = ["${azurerm_network_interface.hub-nic.id}"]
  vm_size                       = "Standard_DS1_v2"
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${local.virtual_machine_name}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "hub-vm-1"
    admin_username = "myadmin"
    admin_password = "Passw0rd1234"
    custom_data    = "${file("cloud-init.sh")}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

# Shared route table for spoke subnets
resource "azurerm_route_table" "custom-route-table" {
  name                          = "custom-route-table"
  location                      = "${azurerm_resource_group.hub-rg.location}"
  resource_group_name           = "${azurerm_resource_group.hub-rg.name}"
  disable_bgp_route_propagation = false

  route {
    name                    = "spoke-routing-to-hub-vent"
    address_prefix          = "192.168.0.0/16"
    next_hop_type           = "VirtualAppliance"
    next_hop_in_ip_address  = "${azurerm_network_interface.hub-nic.private_ip_address}"
  }
}



# Wrkgrp1 Networking
resource "azurerm_resource_group" "wrkgrp1-rg" {
  name     = "CS-wrkgrp1-rg"
  location = "${var.location}"
}

resource "azurerm_virtual_network" "wrkgrp1-vnet" {
  name                = "wrkgrp1-vnet"
  resource_group_name = "${azurerm_resource_group.wrkgrp1-rg.name}"
  location            = "${azurerm_resource_group.wrkgrp1-rg.location}"
  address_space       = ["192.168.1.0/24"]
}
resource "azurerm_subnet" "wrkgrp1-subnet1" {
  name                 = "wrkgrp1-subnet1"
  resource_group_name  = "${azurerm_resource_group.wrkgrp1-rg.name}"
  virtual_network_name = "${azurerm_virtual_network.wrkgrp1-vnet.name}"
  route_table_id       = "${azurerm_route_table.custom-route-table.id}"
  address_prefix       = "192.168.1.0/24"
}

resource "azurerm_subnet_route_table_association" "route1" {
  subnet_id      = "${azurerm_subnet.wrkgrp1-subnet1.id}"
  route_table_id = "${azurerm_route_table.custom-route-table.id}"
}


# Wrkgrp2 Networking
resource "azurerm_resource_group" "wrkgrp2-rg" {
  name     = "CS-wrkgrp2-rg"
  location = "${var.location}"
}

resource "azurerm_virtual_network" "wrkgrp2-vnet" {
  name                = "wrkgrp2-vnet"
  resource_group_name = "${azurerm_resource_group.wrkgrp2-rg.name}"
  location            = "${azurerm_resource_group.wrkgrp2-rg.location}"
  address_space       = ["192.168.2.0/24"]
}
resource "azurerm_subnet" "wrkgrp2-subnet1" {
  name                 = "wrkgrp2-subnet1"
  resource_group_name  = "${azurerm_resource_group.wrkgrp2-rg.name}"
  virtual_network_name = "${azurerm_virtual_network.wrkgrp2-vnet.name}"
  route_table_id       = "${azurerm_route_table.custom-route-table.id}"
  address_prefix       = "192.168.2.0/24"
}

resource "azurerm_subnet_route_table_association" "route2" {
  subnet_id      = "${azurerm_subnet.wrkgrp2-subnet1.id}"
  route_table_id = "${azurerm_route_table.custom-route-table.id}"
}

# ###########################
# BEGIN VNET PEERING
# ###########################

# Hub to wrkgrp1 peering
resource "azurerm_virtual_network_peering" "hub-to-wrkgrp1" {
  name                         = "hub-to-wrkgrp1"
  resource_group_name          = "${azurerm_resource_group.hub-rg.name}"
  virtual_network_name         = "${azurerm_virtual_network.hub-vnet.name}"
  remote_virtual_network_id    = "${azurerm_virtual_network.wrkgrp1-vnet.id}"
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false 
}

# Spoke1 to hub peering
resource "azurerm_virtual_network_peering" "wrkgrp1-to-hub" {
  name                         = "wrkgrp1-to-hub"
  resource_group_name          = "${azurerm_resource_group.wrkgrp1-rg.name}"
  virtual_network_name         = "${azurerm_virtual_network.wrkgrp1-vnet.name}"
  remote_virtual_network_id    = "${azurerm_virtual_network.hub-vnet.id}"
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# Hub to wrkgrp2 peering
resource "azurerm_virtual_network_peering" "hub-to-wrkgrp2" {
  name                         = "hub-to-wrkgrp2"
  resource_group_name          = "${azurerm_resource_group.hub-rg.name}"
  virtual_network_name         = "${azurerm_virtual_network.hub-vnet.name}"
  remote_virtual_network_id    = "${azurerm_virtual_network.wrkgrp2-vnet.id}"
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
}

# Spoke1 to hub peering
resource "azurerm_virtual_network_peering" "wrkgrp2-to-hub" {
  name                         = "wrkgrp2-to-hub"
  resource_group_name          = "${azurerm_resource_group.wrkgrp2-rg.name}"
  virtual_network_name         = "${azurerm_virtual_network.wrkgrp2-vnet.name}"
  remote_virtual_network_id    = "${azurerm_virtual_network.hub-vnet.id}"
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# ###########################
# . END VNET PEERING SECTION
# ###########################

# WRKGRP VM SECTION
locals {
  virtual_machine_name = "wrkgrp-vm"
}

#######################################################################
# HUB VM SECTION
resource "azurerm_public_ip" "hub-pip" {
  name                = "hub-pip"
  location            = "${azurerm_resource_group.hub-rg.location}"
  resource_group_name = "${azurerm_resource_group.hub-rg.name}"
  allocation_method   = "Dynamic"
}



#######################################################################
# VM1 SECTION
/*
resource "azurerm_public_ip" "wrkgrp1-pip" {
  name                = "wrkgrp1-pip"
  allocation_method   = "Dynamic"
}
*/
resource "azurerm_network_interface" "nic" {
  name                      = "vm-nic"
  location                  = "${azurerm_resource_group.wrkgrp1-rg.location}"
  resource_group_name       = "${azurerm_resource_group.wrkgrp1-rg.name}"
  network_security_group_id = "${azurerm_network_security_group.basic-nsg.id}"
  enable_ip_forwarding      = true

  ip_configuration {
    name                          = "primary"
    subnet_id                     = "${azurerm_subnet.wrkgrp1-subnet1.id}"
    private_ip_address_allocation = "Dynamic"
 #   public_ip_address_id          = "${azurerm_public_ip.wrkgrp1-pip.id}"
  }
}

resource "azurerm_virtual_machine" "wrkgrp1-vm" {
  name                          = "wrkgrp1-vm"
  location                      = "${azurerm_resource_group.wrkgrp1-rg.location}"
  resource_group_name           = "${azurerm_resource_group.wrkgrp1-rg.name}"
  primary_network_interface_id  = "${azurerm_network_interface.nic.id}"
  network_interface_ids         = ["${azurerm_network_interface.nic.id}"]
  vm_size                       = "Standard_DS1_v2"
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${local.virtual_machine_name}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${local.virtual_machine_name}-1"
    admin_username = "myadmin"
    admin_password = "Passw0rd1234"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

#######################################################################
# VM2
/*
resource "azurerm_public_ip" "wrkgrp2-pip" {
  name                = "wrkgrp2-pip"
  location            = "${azurerm_resource_group.wrkgrp2-rg.location}"
  resource_group_name = "${azurerm_resource_group.wrkgrp2-rg.name}"
  allocation_method   = "Dynamic"
}
*/
resource "azurerm_network_interface" "nic2" {
  name                      = "vm-nic"
  location                  = "${azurerm_resource_group.wrkgrp2-rg.location}"
  resource_group_name       = "${azurerm_resource_group.wrkgrp2-rg.name}"
  network_security_group_id = "${azurerm_network_security_group.basic-nsg.id}"
  enable_ip_forwarding      = true

  ip_configuration {
    name                          = "primary"
    subnet_id                     = "${azurerm_subnet.wrkgrp2-subnet1.id}"
    private_ip_address_allocation = "Dynamic"
 #   public_ip_address_id          = "${azurerm_public_ip.wrkgrp2-pip.id}"
  }
}

resource "azurerm_virtual_machine" "wrkgrp2-vm" {
  name                          = "wrkgrp2-vm"
  location                      = "${azurerm_resource_group.wrkgrp2-rg.location}"
  resource_group_name           = "${azurerm_resource_group.wrkgrp2-rg.name}"
  primary_network_interface_id  = "${azurerm_network_interface.nic2.id}"
  network_interface_ids         = ["${azurerm_network_interface.nic2.id}"]
  vm_size                       = "Standard_DS1_v2"
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${local.virtual_machine_name}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${local.virtual_machine_name}-2"
    admin_username = "myadmin"
    admin_password = "Passw0rd1234"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}
