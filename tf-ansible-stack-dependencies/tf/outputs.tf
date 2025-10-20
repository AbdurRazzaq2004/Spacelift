output "aws_instances" {
  description = "List of public IPs for created instances"
  value       = [for inst in aws_instance.this : inst.public_ip]
}

output "instance_map" {
  description = "Map of instance name to public IP"
  value = { for i, inst in aws_instance.this : aws_instance.this[i].tags["Name"] => inst.public_ip }
}

output "first_instance_ip" {
  description = "Public IP of the first instance (if any)"
  value       = length(aws_instance.this) > 0 ? aws_instance.this[0].public_ip : ""
}
