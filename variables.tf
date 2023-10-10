variable "proxy_service_address" {
  type        = string
  description = "Host"
}

variable "aws_region" {
  type        = string
  description = "Region in which to deploy AWS resources"
}

variable "cidr_vpc" {
  description = "CIDR block for VPC"
  default     = "10.1.0.0/16"
}

variable "cidr_subnet" {
  description = "CIDR block for subnet"
  default     = "10.1.0.0/20"
}

variable "ssh_key" {
  description = "AWS SSH key"
  default     = "foo"
}

variable "cloudflare_key" {
  type        = string
  description = "API key for Cloudflare user"
}

variable "cloudflare_email" {
  type        = string
  description = "Email for Cloudflare user"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "UUID of Cloudflare Zone for DNS record(s)"
}
