# Talos Linux AWS Kubernetes Terraform

Terraform code for creating a production-ready Kubernetes cluster in AWS using [Talos Linux](https://talos.dev).

[![Terraform](https://img.shields.io/badge/Terraform-1.x-blue.svg)](https://www.terraform.io/)
[![Talos](https://img.shields.io/badge/Talos-v1.7.6-orange.svg)](https://talos.dev/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.30.5-blue.svg)](https://kubernetes.io/)

## Features

- 🚀 **Automated Deployment**: Complete cluster setup with single `terraform apply`
- 🔒 **Secure by Default**: Talos Linux immutable OS with minimal attack surface
- 📈 **Auto-Scaling**: Configurable worker node groups with AWS Auto Scaling
- 🌐 **CNI**: Cilium for networking with Hubble observability
- 🔄 **GitOps Ready**: Optional ArgoCD installation for declarative deployments
- 💾 **Persistent Storage**: Optional AWS EBS CSI driver integration
- 🔗 **Service Mesh**: Optional Linkerd installation
- 📊 **Monitoring**: Built-in support for observability stack

<details>
<summary>References</summary>

- [Talos AWS Terraform Example](https://github.com/siderolabs/contrib/tree/main/examples/terraform/aws)
- [Talos Documentation](https://talos.dev/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

</details>

---

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Modules](#modules)
- [ArgoCD Configuration](#argocd-configuration)
- [Post-Deployment](#post-deployment)
- [Troubleshooting](#troubleshooting)
- [Cost Optimization](#cost-optimization)
- [Security](#security)

---

## Prerequisites

### Required Tools

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.28
- [talosctl](https://www.talos.dev/latest/introduction/getting-started/) >= 1.7

### AWS Requirements

- AWS Account with appropriate permissions
- EC2 instance limits (at least 3 instances for production)
- VPC with available IP space (default: 172.31.0.0/16)
- S3 bucket for remote state (recommended)

### Verify Setup

```bash
# Check tool versions
terraform version
aws --version
kubectl version --client
talosctl version --client

# Verify AWS credentials
aws sts get-caller-identity
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Cloud                            │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                    VPC (172.31.0.0/16)               │  │
│  │                                                      │  │
│  │  ┌──────────────┐      ┌─────────────────────────┐ │  │
│  │  │   Internet   │      │  Network Load Balancer  │ │  │
│  │  │   Gateway    │◄─────┤  (Kubernetes API:6443)  │ │  │
│  │  └──────────────┘      └─────────────────────────┘ │  │
│  │         │                         │                │  │
│  │  ┌──────▼────────────────────────▼──────────────┐ │  │
│  │  │            Public Subnets (3 AZs)            │ │  │
│  │  └──────┬────────────────────┬──────────────────┘ │  │
│  │         │                    │                    │  │
│  │  ┌──────▼───────────┐ ┌──────▼──────────────┐   │  │
│  │  │  Control Plane   │ │   Worker Nodes      │   │  │
│  │  │  Auto Scaling    │ │   Auto Scaling      │   │  │
│  │  │  Group (1-3)     │ │   Group (2-10)      │   │  │
│  │  │  ┌─────────────┐ │ │  ┌────────────────┐ │   │  │
│  │  │  │ Talos Linux │ │ │  │  Talos Linux   │ │   │  │
│  │  │  │   t3.small  │ │ │  │    t3.small    │ │   │  │
│  │  │  └─────────────┘ │ │  └────────────────┘ │   │  │
│  │  └──────────────────┘ └─────────────────────┘   │  │
│  │                                                  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  Kubernetes Services:                                   │
│  • Cilium (CNI)                                        │
│  • CoreDNS                                             │
│  • ArgoCD (Optional)                                   │
│  • AWS EBS CSI Driver (Optional)                       │
│  • Linkerd (Optional)                                  │
│  • Cluster Autoscaler (Optional)                       │
└─────────────────────────────────────────────────────────┘
```

### Component Details

- **Control Plane**: Runs Kubernetes control plane components (API server, scheduler, controller manager)
- **Worker Nodes**: Run application workloads with automatic scaling
- **Cilium**: CNI for networking with eBPF-based security and observability
- **Talos Linux**: Immutable, minimal Linux OS designed for Kubernetes

---

## Quick Start

### 1. (Optional) Set up Remote State Backend

For production use, it's recommended to use remote state storage:

```bash
cd bootstrap-backend
terraform init
terraform apply
cd ..
```

This creates an S3 bucket and DynamoDB table for state storage. After creation, uncomment the backend configuration in `backend.tf` and run `terraform init` to migrate your state.

See [bootstrap-backend/README.md](bootstrap-backend/README.md) for details.

### 2. Configure Your Cluster

Create a `terraform.tfvars` file with your desired configuration:

```hcl
# Region and Naming
region       = "us-east-1"
project_name = "my-talos-cluster"

# Cluster Size - IMPORTANT: worker_nodes_min MUST be > 0 for workloads
control_plane_nodes              = 1  # 1 or 3 for HA
control_plane_node_instance_type = "t3.small"
worker_nodes_min                 = 2  # Minimum 2 recommended
worker_nodes_max                 = 5  # Maximum for auto-scaling
worker_node_instance_type        = "t3.small"

# Versions
talos_version      = "v1.7.6"
kubernetes_version = "1.30.5"
cilium_version     = "1.16.1"

# Access Control - Restrict in production!
talos_api_allowed_cidr      = "0.0.0.0/0"  # Change to your IP
kubernetes_api_allowed_cidr = "0.0.0.0/0"  # Change to your IP

# Optional Components
post_install = {
  argocd = {
    enabled             = false  # Enable for GitOps
    git_url             = ""
    git_branch          = "main"
    git_path            = "bootstrap"
    ssh_key             = ""
    admin_password_hash = ""
  }
  extras = {
    ebs        = false  # AWS EBS persistent volumes
    linkerd    = false  # Service mesh
    autoscaler = false  # Cluster autoscaler
  }
}
```

**⚠️ Critical Configuration Notes:**

1. **Worker Nodes**: `worker_nodes_min` MUST be set to at least 2 for production workloads. Setting it to 0 will prevent pods from scheduling.

2. **Security**: Change `talos_api_allowed_cidr` and `kubernetes_api_allowed_cidr` to your specific IP address or IP range in production.

3. **High Availability**: For production, use `control_plane_nodes = 3` for HA.

See [variables.tf](variables.tf) for all available configuration options.

---

## Configuration

### Essential Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `region` | AWS region | `us-east-1` | Yes |
| `project_name` | Cluster name prefix | `talos-cluster` | Yes |
| `worker_nodes_min` | Minimum worker nodes | `2` | Yes |
| `worker_nodes_max` | Maximum worker nodes | `3` | Yes |
| `control_plane_nodes` | Number of control plane nodes | `1` | Yes |

### Instance Types

Choose based on your workload:

- **Development**: `t3.small` (2 vCPU, 2GB RAM) - ~$15/month per node
- **Production**: `t3.medium` or larger (2 vCPU, 4GB RAM) - ~$30/month per node
- **High Performance**: `c5.large` or `m5.large`

### Network Configuration

```hcl
# Custom VPC CIDR (optional)
vpc_cidr = "172.31.0.0/16"

# Subnet setup - automatically split across 3 AZs
# Calculated as: vpc_cidr split into /20 subnets
```

---

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

After completion, you'll have `kubeconfig` and `talosconfig` files in your directory.

## Modules

* Cloud Infra - Creates the cloud infastructure required for the cluster
    * VPC, Loadbalancer, security groups, autoscaling groups

* Talos
    * Config - Creates machine configs (applied as user data to the autoscaling group launch configs)
    * Bootstrap - Bootstraps Talos and creates kubeconfig

* Post Install
    * Bootstrap Argo CD (optional - disabled by default, configurable by the `post_install` terraform variable)
        * Installs Argo CD via Helm chart
        * Configures Git repository credentials for GitOps
        * Creates a bootstrap Application that syncs your GitOps repo
        * Creates service account for AWS EBS CSI Driver and store credentials in a secret
        * Creates keys for linkerd / cert manager to use
        * Creates config secrets for autoscaler
    * Installs Cilium and creates keys for hubble to use cert-manager


When Terraform has completed, there will be a `kubeconfig` and `talosconfig` file in your working directory; after about a minute after completion you should have a functional cluster

See `variables.tf` for available variables and descriptions

## Argo CD Configuration

To enable Argo CD for GitOps, configure the `post_install` variable in your `terraform.tfvars`:

```hcl
post_install = {
  argocd = {
    enabled             = true
    git_url             = "ssh://git@github.com/your-org/your-gitops-repo"
    git_branch          = "main"
    git_path            = "bootstrap"
    ssh_key             = file("~/.ssh/your_gitops_key")
    admin_password_hash = "" # Optional: bcrypt hash of admin password
  }
  extras = {
    ebs        = true  # AWS EBS CSI Driver
    linkerd    = true  # Service mesh
    autoscaler = true  # Cluster Autoscaler
  }
}
```

See [argocd-bootstrap-example.yaml](argocd-bootstrap-example.yaml) for examples of how to structure your GitOps repository.