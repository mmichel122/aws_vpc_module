# SIMPLE VPC
# Get AZs
data "aws_availability_zones" "available" {}

# Create VPC
resource "aws_vpc" "vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name   = "${var.env_name} VPC"
    Deploy = "vpc"
  }
}

# Create Internet gateway
resource "aws_internet_gateway" "vpc" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags = {
    Name   = "${var.env_name} Internet Gateway"
    Deploy = "vpc"
  }
}

# Create Public Subnets
resource "aws_subnet" "Public_subnet" {
  count             = "${var.sub_count}"
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "${cidrsubnet(var.vpc_cidr, 8, count.index + 1)}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"

  tags = {
    Name   = "${var.env_name}  Public Subnet AZ${count.index + 1}"
    Deploy = "vpc"
  }
}

# Create Nat gateway
resource "aws_nat_gateway" "gw" {
  count         = "${var.sub_count}"
  allocation_id = "${element(aws_eip.nat.*.id, count.index)}"
  subnet_id     = "${element(aws_subnet.Public_subnet.*.id, count.index)}"
}

# Create EIP for the Nat Gateway.
resource "aws_eip" "nat" {
  count = "${var.sub_count}"
  vpc   = true
}

# Create Private Subnets
resource "aws_subnet" "Private_subnet" {
  count             = "${var.sub_count}"
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "${cidrsubnet(var.vpc_cidr, 8, count.index + 11)}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"

  tags = {
    Name   = "${var.env_name}  Private Subnet AZ${count.index + 1}"
    Deploy = "vpc"
  }
}

# Create Public Route Table for Internet Access
resource "aws_route_table" "public_vpc" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.vpc.id}"
  }

  tags = {
    Name   = "${var.env_name} Public Route Table"
    Deploy = "vpc"
  }
}

# Create Private Route table for Internet access
resource "aws_route_table" "private_vpc" {
  count  = "${var.sub_count}"
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${element(aws_nat_gateway.gw.*.id, count.index)}"
  }

  tags = {
    Name   = "${var.env_name} Private Route Table ${count.index + 1}"
    Deploy = "vpc"
  }
}

resource "aws_route_table_association" "private" {
  count          = "${var.sub_count}"
  subnet_id      = "${element(aws_subnet.Private_subnet.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private_vpc.*.id, count.index)}"
}

resource "aws_route_table_association" "public" {
  count          = "${var.sub_count}"
  subnet_id      = "${element(aws_subnet.Public_subnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.public_vpc.id}"
}

# Create Security Group
resource "aws_security_group" "Server_SG" {
  name        = "${var.env_name}_Security_SG"
  description = "Used for access the instances"
  vpc_id      = "${aws_vpc.vpc.id}"

  #SSH

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Redirected Port

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #HTTP

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
