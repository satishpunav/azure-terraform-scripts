## Example: Hub and Spoke Networking with Linux NVA 

This example provides an Azure Hub and Spoke networking example with 3 vnets.  1 VNet is the hub network and the other 2 vnets are spoke networks.  A Linux VM resides on each network.  The Linux VM in the Hub network provides routing services (NVA) so that the spokes vnets can communicate with one another.

Noteworthy:
* NSG attached to all Nics is located in the Hub Resource Group (RG)
* Custom Route Table assigned to the spoke subnets is also in the Hub RG
* Both route_table_id and azurerm_subnet_route_table_association must be set for custom route table to be assigned correctly to an Azure subnet.  (see https://github.com/terraform-providers/terraform-provider-azurerm/issues/2358.  Anomolous behavior will occur if you only provide the azurerm_subnet_route_table_association as of the current Azure Provider release.
* cloud-init.sh script is attached to the Hub VM's custom_data so that ip_forwarding is setup for routing purposes.

