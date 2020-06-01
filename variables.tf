variable hostname {
  type = string
  default = "vault"
}

variable key_name {
  type    = string
  default = "go"
}

variable tags {
  type = map
  default = {
    TTL   = "48"
    owner = "Grant Orchard"
  }
}

variable instance_type {
  type    = string
  default = "t2.medium"
}

variable instance_profile_path {
  description = "Path in which to create the IAM instance profile."
  default     = "/"
}

variable slack_webhook {
  type = string
  default = ""
}

variable private_ip {
  type = string
  default = "10.0.101.161"
}