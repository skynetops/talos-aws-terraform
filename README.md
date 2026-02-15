# Talos Linux AWS Kubernetes Terraform

Terraform code for creating a Kubernetes cluster in AWS using [Talos Linux](https://talos.dev)

<details>
<summary>References</summary>

[Talos AWS Terraform Example](https://github.com/siderolabs/contrib/tree/main/examples/terraform/aws)

</details>

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

Create a `terraform.tfvars` file (see `terraform.tfvars` for a single-node example) or customize the defaults in `variables.tf`.

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