terraform {
  required_version = ">= 1.9"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9.9"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}
