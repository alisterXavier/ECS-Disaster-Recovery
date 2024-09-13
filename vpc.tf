resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/20"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true
   tags = {
    Name = "CloudOpsBlend"
  }
}
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  depends_on = [ aws_vpc.vpc ]
}

resource "aws_subnet" "private_subnets" {
  count             = length(local.private_subnets)
  vpc_id            = aws_vpc.vpc.id
  availability_zone = local.private_subnets[count.index].az
  cidr_block        = local.private_subnets[count.index].cidr
  tags = {
    "Private"                             = true
    "Name"                                = "private-${local.private_subnets[count.index].az}"
    "kubernetes.io/role/internal-elb"     = "1"
    "kubernetes.io/cluster/CloudOpsBlend" = "owned"
  }
}
resource "aws_subnet" "public_subnets" {
  count                   = length(local.public_subnets)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = local.public_subnets[count.index].az
  cidr_block              = local.public_subnets[count.index].cidr
  map_public_ip_on_launch = true
  tags = {
    "Public"                              = true
    "Name"                                = "public-${local.public_subnets[count.index].az}"
    "kubernetes.io/role/elb"              = "1"
    "kubernetes.io/cluster/CloudOpsBlend" = "owned"
  }
}

resource "aws_eip" "eip" {
  tags = {
    Name = "Nat"
  }
}
resource "aws_nat_gateway" "nat" {
  subnet_id     = aws_subnet.public_subnets[0].id
  allocation_id = aws_eip.eip.id
  depends_on    = [aws_subnet.public_subnets, aws_eip.eip]
  tags = {
    Name = "nat"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  depends_on = [aws_internet_gateway.internet_gateway, aws_vpc.vpc]
  tags = {
    Name = "public"
  }
}
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  depends_on = [ aws_nat_gateway.nat ]
  tags = {
    Name = "private"
  }
}
resource "aws_route_table_association" "public_route_table_association" {
  count          = length(aws_subnet.public_subnets)
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnets[count.index].id
}
resource "aws_route_table_association" "private_route_table_association" {
  count          = length(aws_subnet.private_subnets)
  route_table_id = aws_route_table.private_route_table.id
  subnet_id      = aws_subnet.private_subnets[count.index].id
}
