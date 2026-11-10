# homelab-k8s

Kubernetes lab running on local KVM, provisioned end-to-end as code.
Built as CKA practice and a portfolio project.

> Work in progress.

## Stack

| Layer          | Tool                                   |
|----------------|----------------------------------------|
| VMs            | Terraform + libvirt provider (KVM)     |
| Configuration  | Ansible                                |
| Kubernetes     | kubeadm (1 control plane + 1 worker)   |
| Observability  | Prometheus + Grafana                   |
| CI             | GitHub Actions (lint, validate, scan)  |

## Architecture

_TODO: diagram_

## Usage

Host requirements: Linux with KVM, `libvirt-daemon-system`, Terraform >= 1.9,
and the user in the `libvirt` group.

```bash
cd terraform
terraform init
terraform apply
ssh -i ~/.ssh/homelab_k8s_ed25519 debian@192.168.150.10
```

## Design decisions

_TODO: why kubeadm over kind, why libvirt, etc._

## Troubleshooting log

### VMs fail to start: `Could not open '...qcow2': Permission denied`

- **Symptom:** `terraform apply` creates volumes and network, but every domain fails to start.
  File ownership and modes were correct (`libvirt-qemu`, 0600).
- **Diagnosis:** `journalctl -k` showed `apparmor="DENIED" operation="open"` on the node disks.
  The kernel was rate-limiting the messages (`callbacks suppressed`), so they only showed up when
  reproducing with a single domain (`terraform apply -target`).
- **Root cause:** on Ubuntu, libvirt generates a per-VM AppArmor profile with `virt-aa-helper`.
  It does not resolve disks declared as pool volumes (`<disk type='volume'>`), so the profile had
  no rule for them.
- **Fix:** reference disks by file path (`source.file`). `virt-aa-helper` then adds the overlay
  (`rwk`), its qcow2 backing image (`rk`) and the cloud-init ISO (`rk`) automatically.
  No AppArmor tweaks and no `security_driver = "none"` needed.

## AI assistance

Parts of this project were written with the help of an AI assistant (Claude).
Every change was reviewed and is understood by the author.
