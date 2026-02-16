# Talos Linux AWS Kubernetes Terraform

Terraform code for creating a production-ready Kubernetes cluster in AWS using [Talos Linux](https://talos.dev).

[![Terraform](https://img.shields.io/badge/Terraform-1.x-blue.svg)](https://www.terraform.io/)
[![Talos](https://img.shields.io/badge/Talos-v1.7.6-orange.svg)](https://talos.dev/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.30.5-blue.svg)](https://kubernetes.io/)

---

## 🗺️ Infrastructure Topology

## Visual Infrastructure Map

This project deploys a secure and scalable Kubernetes cluster using Talos Linux on AWS. Here is the visual map of what you are building:

```mermaid
graph TD
    %% Define Nodes
    Users((Users))
    LB[AWS Network Load Balancer]
    
    subgraph Public_Subnet [Public Subnet]
        NAT["NAT Gateway (Optional)"]
    end

    subgraph Private_Subnet [Private Subnet]
        CP["Talos Control Plane (EC2)"]
        W1["Worker Node 1 (EC2)"]
        W2["Worker Node 2 (EC2)"]
    end

    %% Define Connections
    Users --> LB
    LB --> CP
    CP --- W1
    CP --- W2
    W1 & W2 --> NAT
    NAT --> Internet((Internet))

    %% Styling
    style CP fill:#f96,stroke:#333,stroke-width:2px
    style NAT fill:#fff,stroke:#333,stroke-dasharray: 5 5
´´´
### Key Components Explained:

1.  **VPC (Virtual Private Cloud):** Your own private network in the AWS cloud. It's like your house's fence.
2.  **Control Plane:** The "Brain" of Kubernetes. It manages the cluster, schedules applications, and stores the state.
3.  **Worker Nodes:** The "Muscle". This is where your actual applications (like websites, APIs) run.
4.  **Load Balancer:** The "Receptionist". It accepts traffic from the internet (you) and directs it to the right place inside the cluster.
5.  **Talos Linux:** A special, very secure operating system built *only* for Kubernetes. It has no SSH, no console, and is immutable (cannot be changed once started).

---

## 🚀 Quick Start Guide

Follow these steps to get your cluster running in minutes.

### 1. Prerequisites (What you need installed)

*   **Terraform:** The tool that builds the cloud infrastructure. [Download here](https://www.terraform.io/downloads).
*   **AWS CLI:** Command line tool to talk to AWS. [Download here](https://aws.amazon.com/cli/).
*   **kubectl:** The remote control for Kubernetes. [Download here](https://kubernetes.io/docs/tasks/tools/).

### 2. Configure Your Cluster

Create a file named `terraform.tfvars` in this folder. Copy and paste this configuration:

```hcl
region       = "ap-southeast-1"  # Or your preferred AWS region
project_name = "talos-cluster"

# Cluster Size
control_plane_nodes = 1
worker_nodes_min    = 2
worker_nodes_max    = 3

# Instance Types (t3.small is cheapest for testing)
control_plane_node_instance_type = "t3.small"
worker_node_instance_type        = "t3.small"

# Access (Open to world for learning, restrict IPs in production!)
talos_api_allowed_cidr      = "0.0.0.0/0"
kubernetes_api_allowed_cidr = "0.0.0.0/0"

# Features
post_install = {
  argocd = {
    enabled = true  # Installs the GitOps dashboard
  }
}
```

### 3. Deploy (Build it!)

Run these commands in your terminal:

```bash
# 1. Initialize Terraform (Downloads plugins)
terraform init

# 2. Preview changes
terraform plan

# 3. Apply changes (Type 'yes' when asked)
terraform apply
```

☕ **Wait about 5-10 minutes.** Terraform is building your cloud servers.

### 4. Connect to Your Cluster

Once Terraform finishes, you will see a `kubeconfig` file in your folder.

**To use `kubectl` permanently:**
```bash
mkdir -p ~/.kube
cp ./kubeconfig ~/.kube/config
```

**Verify it works:**
```bash
kubectl get nodes
```
*You should see 3 nodes listed as `Ready`.*

---

## 🐙 Accessing ArgoCD (The Dashboard)

ArgoCD is a tool that automatically deploys your applications from Git. We installed it for you!

### 1. Get the Login Password
Run this command to reveal the admin password:
```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d && echo
```

### 2. Find the Website URL
Run this to see the external address:
```bash
kubectl get svc -n argocd argocd-server
```
Look for the **EXTERNAL-IP** (it will look like `xxx.ap-southeast-1.elb.amazonaws.com`).

### 3. Login
1.  Open that URL in your browser (e.g., `https://xxx.elb.amazonaws.com`).
2.  **Ignore the security warning** (it's safe, we just used a self-signed certificate).
3.  **Username:** `admin`
4.  **Password:** (The one you got in Step 1).

---

## 🛠️ Troubleshooting & Maintenance

**System Status:**
- Check all pods: `kubectl get pods -A`
- Check nodes: `kubectl get nodes -o wide`

**Destroying the Cluster (To stop costs):**
When you are done, run this to delete everything:
```bash
terraform destroy
```

---

*Built with ❤️ for simple, scalable Kubernetes on AWS.*
