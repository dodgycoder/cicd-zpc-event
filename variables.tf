variable "resource_group_location" {
  default     = "uksouth"
  description = "Location of the resource group."
 
}

variable "tags" {
  type = map(string)
  default = {
    "name" = "Owner"
    "value" = "Arnab"
  }
}

variable "storage" {
  type = map(string)
  default = {
    "account" = "cybernixbankstaccuklabs"
    "blobname" = "vettingstblob"
    "logger" = "http:\\/\\/aba64bfa387d4488a9ae89ccb0e690b6-1855337e9bab2a0d.elb.eu-west-2.amazonaws.com"
  }
}

variable "resource_group_name_prefix" {
  default     = "RG-AZ-DB-EXPOSURE-POSTURE-LAB"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "ubuntuimage" {
  type = map(string)
  default = {
    "offer" = "0001-com-ubuntu-server-jammy"
    "sku" = "22_04-lts-gen2"
    "publisher" = "Canonical"
    "version" = "latest"
  }
}  