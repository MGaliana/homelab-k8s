# homelab-k8s

[![CI](https://github.com/MGaliana/homelab-k8s/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/MGaliana/homelab-k8s/actions/workflows/ci.yml)

Kubernetes lab running on local KVM, provisioned end-to-end as code.
Built as CKA practice and a portfolio project.

> Work in progress.

## Stack

| Layer          | Tool                                   |
|----------------|----------------------------------------|
| VMs            | Terraform + libvirt provider (KVM)     |
| Configuration  | Ansible                                |
| OS             | Debian 13 (trixie) cloud image         |
| Runtime        | containerd 2.4 (Docker apt repo)       |
| Kubernetes     | kubeadm 1.37 (1 control plane + 1 worker) |
| CNI            | Calico 3.33 (operator, VXLAN cross-subnet) |
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

# Ansible (from the repo root)
uv venv --python 3.13 .venv && uv pip install -r requirements-dev.txt
source .venv/bin/activate
cd ansible
ansible-galaxy collection install -r requirements.yml
terraform -chdir=../terraform output -raw ansible_inventory > inventory/generated/hosts.yml
ansible-playbook site.yml

export KUBECONFIG=~/.kube/homelab-k8s.conf
kubectl get nodes
```

Networks: nodes `192.168.150.0/24`, pods `10.244.0.0/16`, services `10.96.0.0/12`.
Calico's default pod CIDR (`192.168.0.0/16`) was avoided on purpose: it overlaps typical home LANs.

## CI and local checks

Every push and pull request runs [`.github/workflows/ci.yml`](.github/workflows/ci.yml):

| Job | What it checks |
|-----|----------------|
| Lint (pre-commit) | `terraform fmt` / `validate`, TFLint (all rules of the bundled `terraform` ruleset), ansible-lint (`production` profile), YAML syntax, whitespace, private keys |
| Security scan | Checkov on Ansible and the workflow itself (it has no libvirt rules; Terraform is enabled for a future AWS module) |
| Secret scan | gitleaks over the **full git history**, not only the current tree |

The lint job runs the same `.pre-commit-config.yaml` used for local commits, so a clean
local commit means a green lint job. Hardening: `permissions: contents: read`, no secrets,
actions pinned to commit SHAs, `persist-credentials: false`, gitleaks binary verified by sha256.

```bash
# Local setup (once): needs terraform and tflint on PATH
source .venv/bin/activate
pre-commit install
pre-commit run --all-files
```

## Design decisions

- **kubeadm on VMs, not kind/containers.** The CKA exam and real clusters are kubeadm on
  real hosts: upgrades, etcd backup/restore, kubelet troubleshooting with systemd. Running nodes
  as containers would hide exactly that. kind is still a good fit for throwaway clusters in CI.

_TODO: why libvirt, why Calico, etc._

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

### Calico operator in CrashLoopBackOff: `CPU does not support x86-64-v2`

- **Symptom:** nodes stuck `NotReady`; `tigera-operator` crash-looping.
- **Root cause:** without an explicit CPU model, libvirt gives guests a generic `qemu64` CPU
  (no SSE4.2/POPCNT). Current images built for x86-64-v2 abort in glibc at startup.
- **Fix:** `cpu.mode = "host-passthrough"` on the domains. Terraform updates the domain in place,
  but a running VM keeps its CPU until a full power cycle (shutdown + start; an in-guest reboot
  is not enough).

### Version constraints found along the way

- Kubernetes >= 1.36 requires containerd 2.x; Debian trixie ships 1.7, so containerd comes from
  Docker's apt repo. Its config must be replaced: the packaged one disables the CRI plugin.
- containerd 2.4 uses config `version = 4`; a v3 file works but is migrated on every start.
- ansible-core 2.17 (last for Python 3.10) does not support Python 3.13 targets and is EOL,
  so the controller venv uses a uv-managed Python 3.13.

## AI assistance

Parts of this project were written with the help of an AI assistant (Claude).
Every change was reviewed and is understood by the author.
