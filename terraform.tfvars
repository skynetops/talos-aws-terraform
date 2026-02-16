region       = "ap-southeast-1"
project_name = "talos-cluster"

# Single node configuration
control_plane_nodes              = 1
control_plane_node_instance_type = "t3.small"
worker_nodes_min                 = 2
worker_nodes_max                 = 3
worker_node_instance_type        = "t3.small"

# Versions
talos_version      = "v1.7.6"
kubernetes_version = "1.30.5"
cilium_version     = "1.16.1"

# Access - restrict these to your IP for production
talos_api_allowed_cidr      = "0.0.0.0/0"
kubernetes_api_allowed_cidr = "0.0.0.0/0"

# Disable Argo CD and extras for simple deployment
post_install = {
  argocd = {
    enabled             = true
    git_url             = "https://github.com/skynetops/talos-k8s-manifests.git"
    git_branch          = "main"
    git_path            = "bootstrap/app-of-apps"
    ssh_key             = ""
    username            = ""
    password            = ""
    admin_password_hash = ""
  }
  extras = {
    ebs        = false
    linkerd    = false
    autoscaler = false
  }
}
