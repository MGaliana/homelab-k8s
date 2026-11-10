output "nodes" {
  description = "Node name => role and IP. Input for the Ansible inventory."
  value = {
    for name, n in local.nodes : n.hostname => {
      role = n.role
      ip   = n.ip
    }
  }
}

output "ssh_hint" {
  description = "How to reach a node."
  value       = "ssh -i ${trimsuffix(var.ssh_public_key_path, ".pub")} ${var.admin_user}@<ip>"
}

output "ansible_inventory" {
  description = "Ansible YAML inventory. Write it with: terraform output -raw ansible_inventory > ../ansible/inventory/generated/hosts.yml"
  value = yamlencode({
    all = {
      vars = {
        ansible_user                 = var.admin_user
        ansible_ssh_private_key_file = trimsuffix(var.ssh_public_key_path, ".pub")
      }
      children = {
        control_plane = {
          hosts = { for name, n in local.nodes : n.hostname => { ansible_host = n.ip } if n.role == "control-plane" }
        }
        workers = {
          hosts = { for name, n in local.nodes : n.hostname => { ansible_host = n.ip } if n.role == "worker" }
        }
      }
    }
  })
}
