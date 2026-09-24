resource "yandex_vpc_network" "this" {
  name = var.a_vpc_name
}

resource "yandex_vpc_subnet" "this" {
  name           = var.b_subnet_name
  zone           = var.default_zone
  network_id     = yandex_vpc_network.this.id
  v4_cidr_blocks = [var.c_cidr]
}
data "template_file" "cloudinit" {
  template = file("${path.module}/cloud-init.yml")
  vars = {
    ssh_public_key = var.ssh_public_key
  }
}
module "vm" {
  source         = "./modules/vm"
  for_each = local.vms
  env_name       = each.key 
  network_id     = yandex_vpc_network.this.id
  subnet_zones   = [each.value.zone]
  subnet_ids     = [yandex_vpc_subnet.this.id]
  instance_name  = each.value.name
  instance_count = each.value.vm_count
  image_family   = "centos-7-oslogin"
  public_ip      = true
  
  metadata = {
    user-data          = data.template_file.cloudinit.rendered
    serial-port-enable = 1
  }

labels = { 
    owner= "a.sorokin",
    project = "accounting"
     }
}
locals {
  inventory_groups = {
    for group_name, m in module.vm : group_name => [
      for idx, ip in m.external_ip_address : {
        name        = m.instance_names[idx]
        external_ip = ip
        internal_ip = m.internal_ip_address[idx]
        fqdn        = m.fqdn[idx]
      }
    ]
  }
}