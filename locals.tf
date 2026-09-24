locals {
  vms = {
    clickhouse = {
      name = "dev"
      zone = "ru-central1-a"
      vm_count = 1
    }
    vector = {
      name = "dev"
      zone = "ru-central1-a"
      vm_count = 1
   }
    lighthouse = {
      name = "dev"
      zone = "ru-central1-a"
      vm_count = 1
    }
 }
}