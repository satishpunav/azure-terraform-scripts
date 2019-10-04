## Example: Hub and Spoke Networking with Linux NVA 

This example provides an Azure Hub and Spoke networking example with 3 vnets.  1 VNet is the hub network and the other 2 vnets are spoke networks.  A Linux VM resides on each network.  The Linux VM in the Hub network provides routing services (NVA) so that the spoke vnets can communicate with one another.

Noteworthy:
* NSG attached to all Nics is located in the Hub Resource Group (RG)
* Spoke VMs do not have public ips assigned.  The HCL for them is present in main.tf but commented out.
* Custom Route Table assigned to the spoke subnets is also in the Hub RG
* Ignore the WARNING in terraform plan about route_table_id being set.  Both route_table_id and azurerm_subnet_route_table_association must be set for custom route table to be assigned correctly to an Azure subnet.  (see https://github.com/terraform-providers/terraform-provider-azurerm/issues/2358.  Anomolous behavior will occur if you only provide the azurerm_subnet_route_table_association as of Azure Provider release 1.34.
* cloud-init.sh script is attached to the Hub VM's custom_data so that ip_forwarding is setup for routing purposes.

