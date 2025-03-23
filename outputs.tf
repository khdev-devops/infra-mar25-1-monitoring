output "ec2_public_ip" {
  description = "Den publika IP-adressen för EC2-instansen"
  value       = aws_instance.mar25_monitoring.public_ip
}