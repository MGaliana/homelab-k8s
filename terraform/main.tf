locals {
  gateway = cidrhost(var.network_cidr, 1)
  prefix  = tonumber(split("/", var.network_cidr)[1])

  nodes = {
    for name, n in var.nodes : name => merge(n, {
      hostname = "${var.cluster_name}-${name}"
      ip       = cidrhost(var.network_cidr, n.host_index)
    })
  }
}

# --- Storage -----------------------------------------------------------------

resource "libvirt_pool" "this" {
  name = var.cluster_name
  type = "dir"

  target = {
    path = var.pool_path
  }

  create = {
    build     = true
    start     = true
    autostart = true
  }
}

# Downloaded once; every node disk is a copy-on-write overlay on top of it.
resource "libvirt_volume" "base" {
  name = "${var.cluster_name}-base.qcow2"
  pool = libvirt_pool.this.name

  target = {
    format = { type = "qcow2" }
  }

  create = {
    content = { url = var.base_image_url }
  }
}

resource "libvirt_volume" "disk" {
  for_each = local.nodes

  name     = "${each.value.hostname}.qcow2"
  pool     = libvirt_pool.this.name
  capacity = each.value.disk_gib * 1024 * 1024 * 1024

  target = {
    format = { type = "qcow2" }
  }

  backing_store = {
    path   = libvirt_volume.base.path
    format = { type = "qcow2" }
  }
}

# --- Network -----------------------------------------------------------------

resource "libvirt_network" "this" {
  name      = var.cluster_name
  autostart = true

  forward = {
    mode = "nat"
  }

  # No DHCP range: nodes get static addresses from cloud-init.
  ips = [
    {
      address = local.gateway
      prefix  = local.prefix
    }
  ]
}

# --- Cloud-init --------------------------------------------------------------

resource "libvirt_cloudinit_disk" "init" {
  for_each = local.nodes

  name = "${each.value.hostname}-cloudinit"

  user_data = templatefile("${path.module}/templates/user-data.yaml.tftpl", {
    hostname       = each.value.hostname
    admin_user     = var.admin_user
    ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
  })

  meta_data = templatefile("${path.module}/templates/meta-data.yaml.tftpl", {
    hostname = each.value.hostname
  })

  network_config = templatefile("${path.module}/templates/network-config.yaml.tftpl", {
    ip      = each.value.ip
    prefix  = local.prefix
    gateway = local.gateway
  })
}

resource "libvirt_volume" "cloudinit" {
  for_each = local.nodes

  name = "${each.value.hostname}-cloudinit.iso"
  pool = libvirt_pool.this.name

  create = {
    content = { url = libvirt_cloudinit_disk.init[each.key].path }
  }

  # The provider writes the ISO to /tmp, which is wiped on host reboot. That
  # changes the source path and would force a replacement on every plan.
  # cloud-init only runs on first boot, so the copy in the pool is enough.
  # To push new cloud-init content, rebuild the node: terraform apply -replace=...
  lifecycle {
    ignore_changes = [create]
  }
}

# --- Nodes -------------------------------------------------------------------

resource "libvirt_domain" "node" {
  for_each = local.nodes

  name        = each.value.hostname
  type        = "kvm"
  vcpu        = each.value.vcpu
  memory      = each.value.memory_mib
  memory_unit = "MiB"
  running     = true

  # Expose the host CPU model. The default (qemu64) lacks x86-64-v2, which many
  # current images require (e.g. Calico's operator: "CPU does not support x86-64-v2").
  cpu = {
    mode = "host-passthrough"
  }

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
  }

  devices = {
    # Disks are referenced by file path, not by pool volume: on Ubuntu, virt-aa-helper
    # does not resolve type='volume' disks, so AppArmor would deny QEMU access to them.
    disks = [
      {
        source = {
          file = { file = libvirt_volume.disk[each.key].path }
        }
        target = { bus = "virtio", dev = "vda" }
        driver = { type = "qcow2" }
      },
      {
        device = "cdrom"
        source = {
          file = { file = libvirt_volume.cloudinit[each.key].path }
        }
        target = { bus = "sata", dev = "sda" }
      },
    ]

    interfaces = [
      {
        model = { type = "virtio" }
        source = {
          network = { network = libvirt_network.this.name }
        }
      },
    ]

    graphics = [
      {
        vnc = {
          auto_port = true
          listen    = "127.0.0.1"
        }
      },
    ]
  }
}
