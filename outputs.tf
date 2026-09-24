output "all_internal_ips" {
  value = {
    for k, m in module.vm : k => m.internal_ip_address
  }
}
output "all_external_ips" {
  value = {
    for k, m in module.vm : k => m.external_ip_address
  }
}
