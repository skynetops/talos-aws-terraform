resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode({
      global = {
        tolerations = [
          {
            key      = "node.cloudprovider.kubernetes.io/uninitialized"
            operator = "Equal"
            value    = "true"
            effect   = "NoSchedule"
          }
        ]
      }
      server = {
        extraArgs = [
          "--insecure" # For internal access; remove for production with proper TLS
        ]
        service = {
          type = "LoadBalancer"
        }
      }
      configs = {
        secret = {
          argocdServerAdminPassword = var.admin_password_hash
        }
      }
    })
  ]
}

# Create Git repository secret if SSH key is provided
resource "kubernetes_secret" "git_repo" {
  count = var.git_ssh_key != "" ? 1 : 0

  metadata {
    name      = "git-repo-credentials"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type          = "git"
    url           = var.git_url
    sshPrivateKey = var.git_ssh_key
  }

  depends_on = [helm_release.argocd]
}

# Bootstrap application - points to your GitOps repo
resource "kubernetes_manifest" "bootstrap_app" {
  count = var.git_url != "" ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "bootstrap"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.git_url
        targetRevision = var.git_branch
        path           = var.git_path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    kubernetes_secret.git_repo
  ]
}
