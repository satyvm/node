output "instance_public_ip" {
  description = "Public IP address of the Ethereum Node"
  value       = aws_instance.ethereum_node.public_ip
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = "ssh -i <path-to-your-key.pem> ubuntu@${aws_instance.ethereum_node.public_ip}"
}

output "data_volume_id" {
  description = "ID of the persistent Ethereum data volume"
  value       = aws_ebs_volume.ethereum_data.id
}
