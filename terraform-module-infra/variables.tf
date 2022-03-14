variable "inputs" {}
variable "nsg_rules" {
  default     = []
}
locals {
  inputs                                      = merge(var.inputs)
  rgs                                         = try(merge(var.inputs.rgs), {})
  mgmt                                        = try(merge(var.inputs.mgmt), {})
  vnets                                       = try(merge(var.inputs.vnets), {})
  routes                                      = try(merge(var.inputs.routes), {})
  nsgs                                        = try(merge(var.inputs.nsgs), {})
  netapp                                      = try(merge(var.inputs.netapp), {})
  vngs                                        = try(merge(var.inputs.vngs), {})
  firewalls                                   = try(merge(var.inputs.firewalls), {})
  azurefiles                                  = try(merge(var.inputs.azurefiles), {})
  rbac                                        = try(merge(var.inputs.rbac), {})
  security                                    = try(merge(var.inputs.security_center), {})
  tags                                        = try(merge(var.inputs.tags), {})
}