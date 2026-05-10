provider "aws" {
  region = var.aws_region
}

resource "aws_security_group" "ethereum_node" {
  name        = "ethereum_node_sg"
  description = "Security group for Ethereum Node"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "Nethermind P2P TCP"
    from_port   = 30303
    to_port     = 30303
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Nethermind P2P UDP"
    from_port   = 30303
    to_port     = 30303
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Lighthouse P2P TCP"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Lighthouse P2P UDP"
    from_port   = 9000
    to_port     = 9000
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "ethereum_node" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.ethereum_node.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name = "Ethereum Node (Ephemery)"
  }
}

resource "aws_ebs_volume" "ethereum_data" {
  availability_zone = aws_instance.ethereum_node.availability_zone
  size              = var.volume_size
  type              = "gp3"
  snapshot_id       = var.data_volume_snapshot_id
  iops              = var.data_volume_iops
  throughput        = var.data_volume_throughput

  tags = {
    Name = "Ethereum Node Data (Ephemery)"
  }
}

resource "aws_volume_attachment" "ethereum_data" {
  device_name = var.data_volume_device_name
  volume_id   = aws_ebs_volume.ethereum_data.id
  instance_id = aws_instance.ethereum_node.id
}
