# Outputs
output "vpc" {
  value = aws_vpc.vpc.id
}

output "public_subnets" {
  value = aws_subnet.Public_subnet.*.id
}

output "private_subnets" {
  value = aws_subnet.Private_subnet.*.id
}
