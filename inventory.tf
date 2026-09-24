resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tftpl", {
    groups = local.inventory_groups
  })
  filename = "${path.module}/inventory/prod.yml"
}