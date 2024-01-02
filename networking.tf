#stores all availabilty zones present in the provider region by name
locals {
  azs = data.aws_availability_zones.available.names
}

data "aws_availability_zones" "available" {}

#random_id will generate a unique name for any resources that  its linked to, if we deploy multiple resources they will have unique names.
resource "random_id" "random" {
  byte_length = 2
}

#create VPC
resource "aws_vpc" "mtc_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "mtc_vpc-${random_id.random.dec}"
  }
  # For changes that may cause downtime but must happen, create_before_destroy will create your new resource before destroying the old resource.
  lifecycle {
    create_before_destroy = true
  }
}

#create internet_gateway for communication between the VPC and the internet
resource "aws_internet_gateway" "mtc_internet_gateway" {
  vpc_id = aws_vpc.mtc_vpc.id

  tags = {
    Name = "mtc_igw-${random_id.random.dec}"
  }
}

#create route table
resource "aws_route_table" "mtc_public_rt" {
  vpc_id = aws_vpc.mtc_vpc.id

  tags = {
    Name = "mtc_public"
  }
}

#create route to the internet through the IGW
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.mtc_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.mtc_internet_gateway.id
}

#default route tabkle for private communication within the vpc
resource "aws_default_route_table" "mtc_private_rt" {
  default_route_table_id = aws_vpc.mtc_vpc.default_route_table_id

  tags = {
    Name = "mtc_private"
  }
}

#create public subnet in all availability_zone present in the region
resource "aws_subnet" "mtc_public_subnet" {
  count                   = length(local.azs) # with length, there is no need to hardcode the digits for your count.index
  vpc_id                  = aws_vpc.mtc_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index) # cidrsubnet perform subnet calculations
  map_public_ip_on_launch = true                                     # we want any ec2 deployed within the public subnet to have a public IP
  availability_zone       = local.azs[count.index]

  tags = {
    Name = "mtc-public-${count.index + 1}" #the count.index + 1 adds a unique number e.g subnet 1, subnet 2...
  }
}

#create private subnet in all availability_zone present in the region
resource "aws_subnet" "mtc_private_subnet" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.mtc_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, length(local.azs) + count.index)
  map_public_ip_on_launch = false
  availability_zone       = local.azs[count.index]

  tags = {
    Name = "mtc-private-${count.index + 1}"
  }
}

#associate route table to all public subnets created so as to communicate with the internet
resource "aws_route_table_association" "mtc_public_assoc" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.mtc_public_subnet[count.index].id
  route_table_id = aws_route_table.mtc_public_rt.id
}

#create security group for ec2
resource "aws_security_group" "mtc_sg" {
  name        = "public_sg"
  description = "security group for public instances"
  vpc_id      = aws_vpc.mtc_vpc.id
}

#create inbound rule and cidr block should be my IP address
resource "aws_security_group_rule" "ingress_all" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = [var.access_ip]
  security_group_id = aws_security_group.mtc_sg.id
}

#create outbound rule to the internet
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.mtc_sg.id
}