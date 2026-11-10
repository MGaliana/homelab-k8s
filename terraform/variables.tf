variable "libvirt_uri" {
  description = "libvirt connection URI."
  type        = string
  default     = "qemu:///system"
}

variable "cluster_name" {
  description = "Prefix for every libvirt object (pool, network, volumes, domains)."
  type        = string
  default     = "homelab-k8s"
}

variable "base_image_url" {
  description = "Debian cloud image used as the read-only backing store for every node disk."
  type        = string
  default     = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
}

variable "admin_user" {
  description = "Sudo user created by cloud-init on every node (SSH key only)."
  type        = string
  default     = "debian"
}

variable "pool_path" {
  description = "Host directory for the libvirt storage pool."
  type        = string
  default     = "/var/lib/libvirt/images/homelab-k8s"
}

variable "network_cidr" {
  description = "Node network (NAT). Must not overlap host routes, the pod CIDR or the service CIDR."
  type        = string
  default     = "192.168.150.0/24"
}

variable "ssh_public_key_path" {
  description = "Public key injected into admin_user via cloud-init."
  type        = string
  default     = "~/.ssh/homelab_k8s_ed25519.pub"
}

variable "nodes" {
  description = "Cluster nodes. host_index is the last octet offset inside network_cidr."
  type = map(object({
    role       = string
    vcpu       = number
    memory_mib = number
    disk_gib   = number
    host_index = number
  }))
  default = {
    cp-1 = { role = "control-plane", vcpu = 2, memory_mib = 2048, disk_gib = 20, host_index = 10 }
    wk-1 = { role = "worker", vcpu = 2, memory_mib = 2048, disk_gib = 20, host_index = 11 }
  }

  validation {
    condition     = alltrue([for n in values(var.nodes) : contains(["control-plane", "worker"], n.role)])
    error_message = "role must be 'control-plane' or 'worker'."
  }

  validation {
    # kubeadm preflight requires >= 2 CPUs and >= 1700 MiB on control-plane nodes.
    condition     = alltrue([for n in values(var.nodes) : n.role != "control-plane" || (n.vcpu >= 2 && n.memory_mib >= 1700)])
    error_message = "control-plane nodes need at least 2 vCPU and 1700 MiB (kubeadm preflight)."
  }
}
