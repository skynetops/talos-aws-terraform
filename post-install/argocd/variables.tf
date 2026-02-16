variable "argocd_version" {
  type        = string
  description = "Version of Argo CD Helm chart to deploy"
  default     = "5.51.6"
}

variable "git_url" {
  type        = string
  description = "Git repository URL for GitOps (SSH format: ssh://git@github.com/org/repo)"
  default     = ""
}

variable "git_branch" {
  type        = string
  description = "Git branch to sync from"
  default     = "main"
}

variable "git_path" {
  type        = string
  description = "Path within the Git repository to sync"
  default     = "bootstrap"
}

variable "git_ssh_key" {
  type        = string
  description = "SSH private key for Git repository access"
  sensitive   = true
  default     = ""
}

variable "git_username" {
  type        = string
  description = "Git username for basic auth (use with personal access token)"
  sensitive   = true
  default     = ""
}

variable "git_password" {
  type        = string
  description = "Git password or personal access token for basic auth"
  sensitive   = true
  default     = ""
}

variable "oauth_client_id" {
  type        = string
  description = "GitHub OAuth Client ID for Argo CD OIDC"
  sensitive   = true
  default     = ""
}

variable "oauth_client_secret" {
  type        = string
  description = "GitHub OAuth Client Secret for Argo CD OIDC"
  sensitive   = true
  default     = ""
}

variable "admin_password_hash" {
  type        = string
  description = "Bcrypt hash of the admin password. Generate with: htpasswd -nbBC 10 '' mypassword | tr -d ':\\n' | sed 's/$2y/$2a/'"
  sensitive   = true
  default     = "" # Empty will use the generated password from Argo CD
}
