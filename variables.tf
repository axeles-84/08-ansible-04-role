variable "cloud_id" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "default_zone" {
  type    = string
  default = "ru-central1-a"
}

variable "a_vpc_name" {
  type = string
  description = "Имя сети" 
}

variable "b_subnet_name" {
  type = string
  description = "Имя подсети"
}

variable "c_cidr" {
  type = string
  description = "Адресс сети"
}
###common vars

variable "ssh_public_key" {
 type        = string
  default     = "your_ssh_ed25519_key"
  description = "ssh-keygen -t ed25519"
}





