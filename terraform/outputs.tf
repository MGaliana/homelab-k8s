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
