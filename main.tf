provider "azurerm" {
  # Whilst version is optional, we /strongly recommend/ using it to pin the version of the Provider being used
  #version = "=1.44.0"
  features {}
}

# Define local variables for Wordpress and MySQL container environment variable values
locals {
        db_name = "web"
        db_user = "wp"
}

# Random string to use with resources requiring unique names
resource "random_string" "random" {
  length = 6
  special = false
  upper = false # lowercase only
  lower = true
}

# Password for Wordpress DB
resource "random_password" "password" {
  length = 16
  special = true
  override_special = "_%@"
}

resource "azurerm_resource_group" "rg" {
  name     = var.name
  location = var.location
}

# Creating File Share for persistent data
resource "azurerm_storage_account" "web_service" {
  name                     = random_string.random.result
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # Locally redundant storage 
}

resource "azurerm_storage_share" "web_service" {
  name                 = var.name
  storage_account_name = azurerm_storage_account.web_service.name
  quota                = 1
}

resource "azurerm_container_registry" "web_service" {
  name                     = random_string.random.result
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  sku                      = "Basic"
  admin_enabled            = false
}

resource "azurerm_container_group" "web_service" {
  name                = var.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_address_type     = "public"
  dns_name_label      = "web-${random_string.random.result}"
  os_type             = "Linux"
  restart_policy = "OnFailure"

  container {
    name   = "wordpress"
    image  = "wordpress:php7.3"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 80
      protocol = "TCP"
    }

    environment_variables = {
        "WORDPRESS_DB_HOST" = "127.0.0.1:3306"
        "WORDPRESS_DB_NAME" = local.db_name
        "WORDPRESS_DB_USER" = local.db_user
    }

    secure_environment_variables = {
        "WORDPRESS_DB_PASSWORD" = random_password.password.result
    }

    # volume {
    #     name = "wordpress"
    #     mount_path = "/var/www/html"
    #     storage_account_name = azurerm_storage_account.web_service.name
    #     storage_account_key = azurerm_storage_account.web_service.primary_access_key
    #     share_name = azurerm_storage_share.web_service.name
    # }
  }

  container {
    name   = "db"
    image  = "mysql:5.7"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 3306
      protocol = "TCP"
    }


    environment_variables = {
        "MYSQL_DATABASE" = local.db_name
        "MYSQL_USER" = local.db_user
        "MYSQL_RANDOM_ROOT_PASSWORD" = "1"
    }

    secure_environment_variables = {
        "MYSQL_PASSWORD" = random_password.password.result
    }

    # volume {
    #     name = "mysql"
    #     mount_path = "/var/lib/mysql"
    #     storage_account_name = azurerm_storage_account.web_service.name
    #     storage_account_key = azurerm_storage_account.web_service.primary_access_key
    #     share_name = azurerm_storage_share.web_service.name
    # }
  }

  tags = {
    environment = "testing"
  }
}