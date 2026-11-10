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

_TODO_

## Design decisions

_TODO: why kubeadm over kind, why libvirt, etc._

## AI assistance

Parts of this project were written with the help of an AI assistant (Claude).
Every change was reviewed and is understood by the author.
