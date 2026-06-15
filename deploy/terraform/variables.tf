variable "image_tag" {
  description = "Container image tag to deploy on fallback clouds."
  type        = string
  default     = "latest"
}

variable "ghcr_owner" {
  description = "GHCR owner (GitHub user/org, lowercase)."
  type        = string
}

variable "image_prefix" {
  description = "Image namespace prefix (ghcr.io/<owner>/<prefix>-<component>)."
  type        = string
  default     = "yieldswarm"
}

variable "primary_health_url" {
  description = "Health URL of the primary (Akash) worker. When healthy, fallbacks stay idle."
  type        = string
  default     = ""
}

# ---- Fallback toggles (ordered preference) --------------------------------
variable "enable_fly" {
  description = "Enable Fly.io fallback deployment."
  type        = bool
  default     = false
}

variable "enable_render" {
  description = "Enable Render fallback deployment."
  type        = bool
  default     = false
}

variable "enable_hetzner" {
  description = "Enable Hetzner Cloud fallback deployment."
  type        = bool
  default     = false
}

# ---- Provider credentials (only required when the matching toggle is on) ---
variable "fly_api_token" {
  type      = string
  default   = ""
  sensitive = true
}

variable "render_api_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "hcloud_token" {
  type      = string
  default   = ""
  sensitive = true
}

variable "fly_region" {
  type    = string
  default = "iad"
}

variable "hetzner_location" {
  type    = string
  default = "ash"
}

variable "hetzner_server_type" {
  type    = string
  default = "cpx11"
}
