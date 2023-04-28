data "azurerm_subscription" "primary" {}
data "azurerm_client_config" "aad" {}

resource "random_string" "random_str_val" {
  special = false
  length =8
  min_upper = 8
}

resource "random_string" "random_str_lower" {
  special = false
  upper = false
  length =8
}

resource "random_password" "sql_admin_password" {
  length  = 20
  special = true
}

resource "azurerm_resource_group" "rg" {
    location = var.resource_group_location
    name = "RG-${var.resource_group_name_prefix}" 
    tags = {
      Owner = var.tags["value"]  
    }

}



# Create virtual network
resource "azurerm_virtual_network" "my_terraform_network" {
  name                = "${format("%s%s",var.resource_group_name_prefix,"-VNET")}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
   tags = {
      Owner = var.tags["value"]  
    }
}

# Create subnet
resource "azurerm_subnet" "my_terraform_subnet" {
  name                 = "${format("%s%s",var.resource_group_name_prefix,"-NETWORK")}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
   
}

# Create public IPs
resource "azurerm_public_ip" "my_terraform_public_ip" {
  name                = "${format("%s%s",var.resource_group_name_prefix,"-PUBIP")}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
   tags = {
      Owner = var.tags["value"]  
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "${format("%s%s",var.resource_group_name_prefix,"-NSG")}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Open-ALL"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "Open-HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
      Owner = var.tags["value"]  
    }  

}

# Create network interface
resource "azurerm_network_interface" "my_terraform_nic" {
  name                = "${format("%s%s",var.resource_group_name_prefix,"-NIC")}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip.id
  }

tags = {
        Owner = var.tags["value"]  
    }   

}

# Create (and display) an SSH key
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#cloud-init-script 
locals {
  custom_data = <<EOF
#!/bin/bash
sudo curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
sudo curl https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list > /etc/apt/sources.list.d/mssql-release.list
sudo add-apt-repository -y ppa:ondrej/php
sudo apt -y update && apt -y upgrade
sudo apt -y install php8.2 php8.2-curl libapache2-mod-php apache2 composer imagemagick unixodbc-dev php8.2-cli php8.2-common php8.2-fpm php8.2-mysql php8.2-zip php8.2-gd php8.2-mbstring php8.2-curl php8.2-xml php8.2-bcmath
sudo ACCEPT_EULA=Y apt-get install -y msodbcsql18
sudo ACCEPT_EULA=Y apt-get install -y mssql-tools18
sudo pecl install sqlsrv
sudo pecl install pdo_sqlsrv
sudo printf "; priority=20\nextension=sqlsrv.so\n" > /etc/php/8.2/mods-available/sqlsrv.ini
sudo printf "; priority=30\nextension=pdo_sqlsrv.so\n" > /etc/php/8.2/mods-available/pdo_sqlsrv.ini
sudo phpenmod -v 8.2 sqlsrv pdo_sqlsrv
sudo systemctl enable apache2
sudo mkdir -p /var/www/data
sudo rm -f /etc/ImageMagick-6/policy.xml
sudo rm -rf /var/www/html/*
sudo git clone https://github.com/dodgycoder/banking-app.git /var/www/html/
cd /var/www/html && sudo sed -i 's/<storageaccount>/${var.storage["account"]}/g' upload.php
cd /var/www/html && sudo sed -i 's/<blobname>/${var.storage["blobname"]}/g' upload.php
cd /var/www/html && sudo sed -i 's/<databaseserver>/db-${random_string.random_str_val.result}/g' login-2.php 
sudo chown -R www-data:www-data /var/www/
sudo systemctl start apache2
EOF
  }


resource "azurerm_role_definition" "app-role" {
  name        = "role-${var.resource_group_name_prefix}"
  scope       = "${data.azurerm_subscription.primary.id}"
  description = "This is a custom role created via Terraform for this web app give permission to all storage accounts, in the future we might need more"

  permissions {
    actions     = ["Microsoft.Resources/subscriptions/resourceGroups/read","Microsoft.Storage/storageAccounts/*"]
    not_actions = []
  }

assignable_scopes = [
    "${data.azurerm_subscription.primary.id}", 
  ]
   

}  


# Create virtual machine
resource "azurerm_linux_virtual_machine" "my_terraform_vm" {
  name                  = "VM-${random_string.random_str_val.result}"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.my_terraform_nic.id]
  size                  = "Standard_B2s"

  os_disk {
    name                 = "Disk-${random_string.random_str_val.result}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name                   = "VM-${random_string.random_str_val.result}"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ssh_key.public_key_openssh
    
  }

  identity {
    type = "SystemAssigned"
  }  

  tags = {
      Owner = var.tags["value"]  
    }  
 
  custom_data = base64encode(local.custom_data)


}

resource "azurerm_role_assignment" "assign_role" {
  name               = azurerm_role_definition.app-role.role_definition_id
  scope              = "${data.azurerm_subscription.primary.id}"
  role_definition_id = azurerm_role_definition.app-role.role_definition_resource_id
  principal_id       = azurerm_linux_virtual_machine.my_terraform_vm.identity[0].principal_id
}

resource "azurerm_storage_account" "app-storage" {
  name                     = var.storage["account"]
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  shared_access_key_enabled = "true"

  tags = {
    Owner = var.tags["value"]
  }
}

resource "azurerm_storage_container" "app-container" {
  name                  = var.storage["blobname"]
  storage_account_name  = azurerm_storage_account.app-storage.name
  container_access_type = "private"
}

resource "azurerm_sql_server" "auth-db" {
  name                         = "db-${random_string.random_str_val.result}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "adminuser"
  administrator_login_password = random_password.sql_admin_password.result
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_sql_database" "example" {
  name                = "userdb"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_resource_group.rg.location
  collation           = "SQL_Latin1_General_CP1_CI_AS"

  # Enable Active Directory authentication
  authentication {
    type                   = "ActiveDirectory"
    azure_active_directory {
      tenant_id               = data.azurerm_client_config.aad.tenant_id
    }
  }
}