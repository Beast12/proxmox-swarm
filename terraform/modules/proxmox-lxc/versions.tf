terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.69"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
