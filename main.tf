data "azurerm_billing_enrollment_account_scope" "sandbox_billing" {
  billing_account_name    = "rohithsandbox-arc"
  enrollment_account_name = "azure-sandbox"
}

resource "azurerm_subscription" "sand_box" {
  subscription_name = "Sandbox_Subscription"
  billing_scope_id  = data.azurerm_billing_enrollment_account_scope.sandbox_billing.id
}

resource "azurerm_resource_group" "rg" {
  name     = var.rgname
  location = var.location
}

resource "azurerm_virtual_network" "vnet-shared-01" {
  name                = "vnet-shared-001"
  location            = var.location
  resource_group_name = var.rgname
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "AzureBastionSubnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.rgname
  virtual_network_name = azurerm_virtual_network.vnet-shared-01.name
  address_prefixes     = ["10.1.0.0/26"]
}

resource "azurerm_public_ip" "pip_001" {
  name                = "Bastion-pip"
  location            = var.location
  resource_group_name = var.rgname
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "Bastion_host" {
  name                = "Bastion"
  location            = var.location
  resource_group_name = var.rgname

  ip_configuration {
    name                 = "Configuration"
    subnet_id            = azurerm_subnet.AzureBastionSubnet.id
    public_ip_address_id = azurerm_public_ip.pip_001.id
  }
}

resource "azurerm_subnet" "snet-adds-01" {
  name                 = "Subnet-Adds"
  resource_group_name  = var.rgname
  virtual_network_name = azurerm_virtual_network.vnet-shared-01.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_network_interface" "adds_nic" {
  name                = "nic"
  location            = var.location
  resource_group_name = var.rgname

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet-adds-01.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "adds1" {
  name                            = "adds-vm"
  location                        = var.location
  resource_group_name             = var.rgname
  size                            = "Standard_F2"
  admin_username                  = "adminuser"
  admin_password                  = "password123!"
  network_interface_ids           = [azurerm_network_interface.adds_nic.id, ]
  disable_password_authentication = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_virtual_wan" "vwan-xx" {
  name                = "vwan"
  location            = var.location
  resource_group_name = var.rgname
}

resource "azurerm_virtual_hub" "vhub-xx" {
  name                = "vhub"
  location            = var.location
  resource_group_name = var.rgname
  virtual_wan_id      = azurerm_virtual_wan.vwan-xx.id
  address_prefix      = "10.4.0.0/16"
}

resource "azurerm_vpn_server_configuration" "pts_server" {
  name                     = "config_server"
  resource_group_name      = var.rgname
  location                 = var.location
  vpn_authentication_types = ["Certificate"]

  client_root_certificate {
    name             = "DigiCert-Federated-ID-Root-CA"
    public_cert_data = ""
  }
}

resource "azurerm_point_to_site_vpn_gateway" "pointtosite" {
  name                        = "pointtosite_vpn"
  location                    = var.location
  resource_group_name         = var.rgname
  virtual_hub_id              = azurerm_virtual_hub.vhub-xx.id
  vpn_server_configuration_id = azurerm_vpn_server_configuration.pts_server.id
  scale_unit                  = 1
  connection_configuration {
    name = "gateway-config"
    vpn_client_address_pool {
      address_prefixes = ["10.4.0.0/24"]
    }
  }
}

resource "azurerm_storage_account" "stg" {
  name                     = "innonproddemo01"
  resource_group_name      = var.rgname
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_sql_server" "sql_server" {
  name                         = "server"
  location                     = var.location
  resource_group_name          = var.rgname
  version                      = "12.0"
  administrator_login          = "user"
  administrator_login_password = "password123!"

  tags = {
    environment = "test"
  }
}

resource "azurerm_sql_database" "sql_xx" {
  name                = "sql-db"
  location            = var.location
  resource_group_name = var.rgname
  server_name         = azurerm_sql_server.sql_server.name

  tags = {
    environment = "test"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_mysql_server" "mysql-server" {
  name                         = "mysqlserver"
  location                     = var.location
  resource_group_name          = var.rgname
  administrator_login          = "user"
  administrator_login_password = "password123!"
  sku_name                     = "GP_Gen5_2"
  storage_mb                   = 5120
  version                      = "5.7"

  auto_grow_enabled            = true
  backup_retention_days        = 7
  geo_redundant_backup_enabled = true
  #infrastucture_encryption_enabled = true
  public_network_access_enabled    = false
  ssl_enforcement_enabled          = true
  ssl_minimal_tls_version_enforced = "TLS1_2"

  tags = {
    environment = "test"
  }
}

resource "azurerm_mysql_database" "mysql-xx" {
  name                = "mysql-db"
  resource_group_name = var.rgname
  #location            = var.location
  server_name = azurerm_mysql_server.mysql-server.name
  charset     = "utf8"
  collation   = "utf8_unicode_ci"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_virtual_network" "vnet-app-01" {
  name                = "vnet-app"
  location            = var.location
  resource_group_name = var.rgname
  address_space       = ["10.2.0.0/16"]
}

resource "azurerm_subnet" "snet-app-01" {
  name                 = "snetapp"
  virtual_network_name = azurerm_virtual_network.vnet-app-01.name
  resource_group_name  = var.rgname
  address_prefixes     = ["10.2.0.0/24"]
}

resource "azurerm_network_interface" "jump_nic" {
  name                = "jumpwin"
  location            = var.location
  resource_group_name = var.rgname

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet-app-01.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "jumpwin1" {
  name                  = "jumpwindows"
  location              = var.location
  resource_group_name   = var.rgname
  size                  = "Standard_F2"
  admin_username        = "adminuser"
  admin_password        = "password123!"
  network_interface_ids = [azurerm_network_interface.jump_nic.id, ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "jumplinux1" {
  name                            = "jumplinux"
  location                        = var.location
  resource_group_name             = var.rgname
  size                            = "Standard_F2"
  admin_username                  = "adminuser"
  admin_password                  = "password123!"
  network_interface_ids           = [azurerm_network_interface.jump_nic.id, ]
  disable_password_authentication = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_subnet" "snet-db-01" {
  name                 = "snet-db"
  virtual_network_name = azurerm_virtual_network.vnet-app-01.name
  resource_group_name  = var.rgname
  address_prefixes     = ["10.2.1.0/24"]
}

resource "azurerm_network_interface" "mssql_nic" {
  name                = "jumpwin"
  location            = var.location
  resource_group_name = var.rgname

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet-db-01.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "mssqlwin1" {
  name                  = "mssqlwindows"
  location              = var.location
  resource_group_name   = var.rgname
  size                  = "Standard_F2"
  admin_username        = "adminuser"
  admin_password        = "password123!"
  network_interface_ids = [azurerm_network_interface.jump_nic.id, ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_mssql_virtual_machine" "mssqlvm" {
  virtual_machine_id               = azurerm_windows_virtual_machine.mssqlwin1.id
  sql_connectivity_port            = 1433
  sql_connectivity_type            = "PRIVATE"
  sql_connectivity_update_username = "user"
  sql_connectivity_update_password = "password123!"

  auto_patching {
    day_of_week                            = "Sunday"
    maintenance_window_duration_in_minutes = 60
    maintenance_window_starting_hour       = 2
  }
}

resource "azurerm_subnet" "snet-privatelink-01" {
  name                 = "privatelinksnet"
  resource_group_name  = var.rgname
  virtual_network_name = azurerm_virtual_network.vnet-app-01.name
  address_prefixes     = ["10.2.2.0/24"]
}

resource "azurerm_public_ip" "pt-pip" {
  name                = "pip-pt"
  sku                 = "Standard"
  location            = var.location
  resource_group_name = var.rgname
  allocation_method   = "Static"
}

resource "azurerm_lb" "loadbalancer" {
  name                = "pt-lb"
  sku                 = "Standard"
  location            = var.location
  resource_group_name = var.rgname

  frontend_ip_configuration {
    name                 = azurerm_public_ip.pt-pip.name
    public_ip_address_id = azurerm_public_ip.pt-pip.id
  }
}

resource "azurerm_private_link_service" "private-link" {
  name                                        = "pt-link"
  resource_group_name                         = var.rgname
  location                                    = var.location
  load_balancer_frontend_ip_configuration_ids = [azurerm_lb.loadbalancer.frontend_ip_configuration[0].id]

  nat_ip_configuration {
    name                       = "primary"
    private_ip_address         = "10.2.1.10"
    private_ip_address_version = "IPv4"
    subnet_id                  = azurerm_subnet.snet-privatelink-01.id
    primary                    = true
  }

  nat_ip_configuration {
    name                       = "secondary"
    private_ip_address         = "10.2.1.11"
    private_ip_address_version = "IPv4"
    subnet_id                  = azurerm_subnet.snet-privatelink-01.id
    primary                    = false
  }
}

resource "azurerm_private_endpoint" "pend-mssql-01" {
  name                = "pendmssql"
  location            = var.location
  resource_group_name = var.rgname
  subnet_id           = azurerm_subnet.snet-privatelink-01.id

  private_service_connection {
    name                           = "service-config"
    private_connection_resource_id = azurerm_sql_server.sql_server.id
    is_manual_connection           = false
  }
}

resource "azurerm_private_endpoint" "pend-mysql-01" {
  name                = "pendmssql"
  location            = var.location
  resource_group_name = var.rgname
  subnet_id           = azurerm_subnet.snet-privatelink-01.id

  private_service_connection {
    name                           = "service-config"
    private_connection_resource_id = azurerm_mysql_server.mysql-server.id
    is_manual_connection           = false
  }
}

resource "azurerm_storage_account" "stxx" {
  name                     = "storagexx"
  location                 = var.location
  resource_group_name      = var.rgname
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_private_endpoint" "pend-stxx-file" {
  name                = "pendstorage"
  location            = var.location
  resource_group_name = var.rgname
  subnet_id           = azurerm_subnet.snet-privatelink-01.id

  private_service_connection {
    name                           = "service-config"
    private_connection_resource_id = azurerm_storage_account.stxx.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv-xx" {
  name                       = "keyvault"
  location                   = var.location
  resource_group_name        = var.rgname
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Get",
    ]

    secret_permissions = [
      "Set",
      "Get",
      "Delete",
      "Purge",
      "Recover"
    ]
  }
}

resource "azurerm_key_vault_secret" "keysec" {
  name         = "secret"
  value        = "rohith"
  key_vault_id = azurerm_key_vault.kv-xx.id
}

resource "azurerm_automation_account" "auto-01" {
  name = "demo-account"
  location = var.location
  resource_group_name = var.rgname
  sku_name = "Basic"
}

resource "azurerm_log_analytics_workspace" "log-01" {
 name = "log-analysis"
 location = var.location
 resource_group_name = var.rgname
 sku = "PerGB2018"
 retention_in_days = 30 
}

resource "azurerm_virtual_network_peering" "peer-01" {
  name                      = "peer_shared_to_app"
  resource_group_name       = var.rgname
  virtual_network_name      = azurerm_virtual_network.vnet-shared-01.name
  remote_virtual_network_id = azurerm_virtual_network.vnet-app-01.id
}

resource "azurerm_virtual_network_peering" "peer-02" {
  name                      = "peer_app_to_shared"
  resource_group_name       = var.rgname
  virtual_network_name      = azurerm_virtual_network.vnet-app-01.name
  remote_virtual_network_id = azurerm_virtual_network.vnet-shared-01.id
}

resource "azurerm_virtual_network_peering" "peer-03" {
  name                      = "peer_shared_to_wan"
  resource_group_name       = var.rgname
  virtual_network_name      = azurerm_virtual_network.vnet-shared-01.name
  remote_virtual_network_id = azurerm_virtual_wan.vwan-xx.id
}

resource "azurerm_virtual_network_peering" "peer-04" {
  name                      = "peer_wan_to_shared"
  resource_group_name       = var.rgname
  virtual_network_name      = azurerm_virtual_wan.vwan-xx.name
  remote_virtual_network_id = azurerm_virtual_network.vnet-shared-01.id
}

resource "azurerm_virtual_network_peering" "peer-05" {
  name                      = "peer_wan_to_app"
  resource_group_name       = var.rgname
  virtual_network_name      = azurerm_virtual_wan.vwan-xx.name
  remote_virtual_network_id = azurerm_virtual_network.vnet-app-01.id
}

resource "azurerm_virtual_network_peering" "peer-06" {
  name                      = "peer_app_to_wan"
  resource_group_name       = var.rgname
  virtual_network_name      = azurerm_virtual_network.vnet-app-01.name
  remote_virtual_network_id = azurerm_virtual_wan.vwan-xx.id
}