# main.tf

terraform {
 required_providers {
 aws = {
    source = "hashicorp/aws"
    version = "~> 5.39"
    }
 }
 required_version = ">= 1.2.0"
}

# Configure the AWS provider
provider "aws" {
  region = "ap-southeast-1"
  profile = "chokchai"
}

# Create a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"  # CIDR Block

  # Enable DNS support and hostname assignment
  enable_dns_support = true
  enable_dns_hostnames = true
}

# Create an Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

# Create a public subnet in the VPC
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block             = "10.0.1.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = true            # Allow instances in this subnet to have public IPs
}

# Create a private subnet in the VPC
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block             = "10.0.10.0/24"  
  availability_zone       = "ap-southeast-1a"   
}

# Create a Route Table for the public subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id
}

# Create a default route pointing to the Internet Gateway
resource "aws_route" "public_route_igw" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_igw.id
}

# Associate the public subnet with the public route table
resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# Create a NAT gateway
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
}

# # Create a new Elastic IP address for the NAT gateway
# resource "aws_instance" "nat_instance" {
#   ami                    = var.ami
#   instance_type          = "t2.micro"
#   subnet_id              = aws_subnet.public_subnet.id
#   associate_public_ip_address = true

#   tags = {
#     Name = "NATGatewayInstance"
#   }
# }

# Create a Route Table for the private subnet
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id
}

# Create a default route pointing to the NAT Gateway in the private route table
resource "aws_route" "private_route_nat" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.nat_gateway.id
}

# Associate the private subnet with the private route table
resource "aws_route_table_association" "private_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_security_group" "wordpress_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "mariadb_sg" {
  vpc_id = aws_vpc.my_vpc.id


  # Allow ICMP (ping) traffic
  ingress {
    from_port   = -1  # -1 means any port
    to_port     = -1  # -1 means any port
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
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

## EC2 in public subnet (wordpress)
resource "aws_instance" "wordpress_instance" {
  ami           = var.ami
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name = "chokchai-chula"
  vpc_security_group_ids = [aws_security_group.wordpress_sg.id]

  tags = {
    Name = "WordpressInstance"
  }
}

## EC2 in private subnet (mairadb)
resource "aws_instance" "mariadb_instance" {
  ami           = var.ami
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.mariadb_sg.id]

  tags = {
    Name = "MariaDBInstance"
  }
}