variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block for SSH access (your IP/32)"
  default     = "0.0.0.0/0"  # CAMBIAR A TU IP DESPUÉS
  type        = string
}

variable "db_username" {
  description = "RDS master username"
  default     = "diagramadmin"
  type        = string
}

variable "db_password" {
  description = "RDS master password"
  sensitive   = true
  type        = string
}
