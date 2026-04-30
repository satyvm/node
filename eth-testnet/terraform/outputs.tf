output "instance_public_ip" {
  description = "Public IP address of the Ethereum Node"
  value       = aws_instance.ethereum_node.public_ip
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = "ssh -i <path-to-your-key.pem> ubuntu@${aws_instance.ethereum_node.public_ip}"
}
