# Terraform scripts for Azure
## Instructions
Install Terraform using the [instructions](https://learn.hashicorp.com/terraform/getting-started/install.html) for your platform.

Create a service principal in Azure by running the following command.
```
az ad sp create-for-rbac --name terraform-sp
```

On Mac/Linux set the following environment variables using the commands below with the information provided in the service principal.  Be sure to pick the correct ARM_ENVIRONMENT for the Azure cloud you are targeting.
```
export ARM_SUBSCRIPTION_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ARM_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ARM_CLIENT_SECRET=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ARM_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ARM_ENVIRONMENT=[usgovernment/public/german/china (chose one)]
```

Execute terraform plan and apply:
```
terraform plan
terraform apply
```
