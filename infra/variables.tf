variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block for SSH access - set to your IP e.g. 1.2.3.4/32"
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

variable "ec2_key_pair_name" {
  description = "Name of an existing EC2 key pair for SSH access"
  type        = string
}

variable "cors_allowed_origin" {
  description = "Allowed origin for backend CORS (e.g. https://yourdomain.com)"
  type        = string
  default     = ""
}
