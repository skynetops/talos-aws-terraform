# Talos Linux AWS Kubernetes Terraform

Terraform code for creating a production-ready Kubernetes cluster in AWS using [Talos Linux](https://talos.dev).

[![Terraform](https://img.shields.io/badge/Terraform-1.x-blue.svg)](https://www.terraform.io/)
[![Talos](https://img.shields.io/badge/Talos-v1.7.6-orange.svg)](https://talos.dev/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.30.5-blue.svg)](https://kubernetes.io/)

---

## 🗺️ Infrastructure Topology

This project deploys a secure and scalable Kubernetes cluster. Here is the visual map of what you are building:

```mermaid
graph TD
    subgraph AWS_Cloud ["AWS Cloud (ap-southeast-1)"]
        subgraph VPC ["VPC (172.31.0.0/16)"]
            IGW[Internet Gateway]
            
            subgraph Public_Subnets ["Public Subnets (Across 3 AZs)"]
                LB[Network Load Balancer]
                NAT[NAT Gateway (Optional)]
                
                subgraph Control_Plane ["Control Plane ASG"]
                    CP1[Talos Control Plane Node]
                end
                
                subgraph Worker_Nodes ["Worker ASG"]
                    W1[Talos Worker Node 1]
                    W2[Talos Worker Node 2]
                end
            end
            
            IGW --> LB
            LB -->|Port 6443| CP1
            CP1 -.->|Internal Communication| W1
            CP1 -.->|Internal Communication| W2
        end
    end

    subgraph User_Access ["User Access"]
        User[You / Developer]
        Kubectl[kubectl / k9s]
        Browser[Web Browser]
    end

    User -->|terraform apply| AWS_Cloud
    Kubectl -->|kubeconfig| LB
    Browser -->|HTTPS| LB
```

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

### 3. Login (Two Options)

- Quick access (default):
  1. Open `https://<EXTERNAL-IP>` in your browser.
  2. Accept the browser warning (self-signed cert). This is expected for the ELB hostname.
  3. Username: `admin`, Password: from Step 1.

- Production TLS (recommended): use a custom domain + ACM certificate
  1. Pick a domain, e.g. `argocd.example.com`, in a Route53 hosted zone.
  2. Request an ACM certificate in the same region as the cluster (e.g., `ap-southeast-1`) and validate via DNS.
  3. Point your domain to the ArgoCD LoadBalancer: create a CNAME `argocd.example.com -> <EXTERNAL-IP>`.
  4. Attach the certificate to the Service LoadBalancer:
     ```bash
     CERT_ARN="arn:aws:acm:ap-southeast-1:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
     kubectl -n argocd annotate svc argocd-server \
       service.beta.kubernetes.io/aws-load-balancer-type=nlb \
       service.beta.kubernetes.io/aws-load-balancer-ssl-cert="$CERT_ARN" \
       service.beta.kubernetes.io/aws-load-balancer-ssl-ports="443"
     ```
  5. Visit `https://argocd.example.com` without warnings.

Notes:
- The Terraform Helm values are aligned to use ports 80/443 with targetPort 8080 and TLS enabled (no `--insecure`).
- You can add annotations via Helm/Terraform later; a domain is NOT mandatory before installing ArgoCD.
- If you prefer ALB + HTTP(S) termination and path routing, install the AWS Load Balancer Controller and use Ingress; this repo currently uses a Service of type LoadBalancer (NLB/TCP).

### Secure TLS with cert-manager (DNS-01 via Route53)

For a trusted certificate on `argocd.skynetdevops.com` without AWS ACM:
1. Ensure `argocd.skynetdevops.com` exists in Route53 and points to the Argo CD LoadBalancer (CNAME -> ELB hostname).
2. Install cert-manager:
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.crds.yaml
   helm repo add jetstack https://charts.jetstack.io
   helm repo update
   helm install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --version v1.14.4
   ```
3. Create an AWS credentials secret (do NOT commit keys). Replace values accordingly:
   ```bash
   kubectl -n cert-manager create secret generic route53-credentials \
     --from-literal=aws_access_key_id=AKIA... \
     --from-literal=aws_secret_access_key=XXXXXXXX
   ```
4. Create a ClusterIssuer (DNS-01 for Route53). Replace `HOSTED_ZONE_ID`, `EMAIL`:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-prod
   spec:
     acme:
       email: EMAIL
       server: https://acme-v02.api.letsencrypt.org/directory
       privateKeySecretRef:
         name: letsencrypt-prod
       solvers:
       - dns01:
           route53:
             hostedZoneID: HOSTED_ZONE_ID
             region: ap-southeast-1
             accessKeyIDSecretRef:
               name: route53-credentials
               key: aws_access_key_id
             secretAccessKeySecretRef:
               name: route53-credentials
               key: aws_secret_access_key
   ```
   Apply it: `kubectl apply -f clusterissuer.yaml`
5. Request the cert in `argocd` namespace:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: Certificate
   metadata:
     name: argocd-server-tls
     namespace: argocd
   spec:
     secretName: argocd-server-tls
     issuerRef:
       name: letsencrypt-prod
       kind: ClusterIssuer
     dnsNames:
       - argocd.skynetdevops.com
   ```
   Apply it: `kubectl apply -f certificate.yaml`
6. Configure Argo CD server to use the cert (Helm values override):
   - Mount the secret and set extraArgs:
     ```yaml
     server:
       extraArgs:
         - --tls-cert=/etc/argocd/tls/tls.crt
         - --tls-key=/etc/argocd/tls/tls.key
       volumes:
         - name: tls
           secret:
             secretName: argocd-server-tls
       volumeMounts:
         - name: tls
           mountPath: /etc/argocd/tls
           readOnly: true
     ```
   Re-run `terraform apply` to update Helm release.
7. Verify: visit `https://argocd.skynetdevops.com` with no browser warnings.

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
