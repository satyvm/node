variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type (must be arm64 for Graviton)"
  default     = "t4g.large"
}

variable "volume_size" {
  description = "Size of the data volume in GB (must be at least the snapshot size when restoring)"
  default     = 50
}

variable "data_volume_snapshot_id" {
  description = "Optional EBS snapshot ID to restore the data volume from"
  type        = string
  default     = null
}

variable "data_volume_iops" {
  description = "Provisioned gp3 IOPS for the data volume"
  type        = number
  default     = 3000
}

variable "data_volume_throughput" {
  description = "Provisioned gp3 throughput in MiB/s for the data volume"
  type        = number
  default     = 125
}

variable "data_volume_device_name" {
  description = "Requested device name for attaching the data volume"
  type        = string
  default     = "/dev/sdf"
}

variable "key_name" {
  description = "Name of the AWS key pair to use for SSH"
  type        = string
}

variable "ssh_cidr" {
  description = "CIDR block allowed to SSH into the node (default is anywhere, restrict to your IP!)"
  type        = string
}
