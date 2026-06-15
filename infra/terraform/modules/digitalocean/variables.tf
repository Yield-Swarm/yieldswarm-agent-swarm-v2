variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "droplet_size" {
  type = string
}

variable "shard_count" {
  type    = number
  default = 2
}

variable "tags" {
  type    = map(string)
  default = {}
}
