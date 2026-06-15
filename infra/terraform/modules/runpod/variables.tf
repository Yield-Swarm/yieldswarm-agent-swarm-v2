variable "environment" {
  type = string
}

variable "pod_template_id" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
