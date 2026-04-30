variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type (must be arm64 for Graviton)"
  default     = "t4g.large"
}

variable "volume_size" {
  description = "Size of the data volume in GB"
  default     = 300
}

variable "key_name" {
  description = "Name of the AWS key pair to use for SSH"
  type        = string
}

variable "ssh_cidr" {
  description = "CIDR block allowed to SSH into the node (default is anywhere, restrict to your IP!)"
  type        = string
}
