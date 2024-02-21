resource "aws_vpc" "assignement_vpc" {
  cidr_block = var.cidr
  tags = merge(var.tags, {
    Name = "assignement_vpc"
    }

  )
}

resource "aws_subnet" "assignement_private_subnet" {
  count             = length(var.availability_zone)
  vpc_id            = aws_vpc.assignement_vpc.id
  cidr_block        = cidrsubnet(var.cidr, 8, count.index)
  availability_zone = element(var.availability_zone, count.index)

  tags = merge(var.tags, {
    Name = format("%s-assignement_private_subnet-${count.index}", var.tags["id"])
    }
  )
}

resource "aws_subnet" "assignement_public_subnet" {
  count      = length(var.availability_zone)
  vpc_id     = aws_vpc.assignement_vpc.id
  cidr_block = cidrsubnet(var.cidr, 6, count.index + 1)

  tags = merge(var.tags, {
    Name = format("%s-assignement_public_subnet-${count.index}", var.tags["id"])
    }
  )
}

resource "aws_internet_gateway" "assignement_igw" {
  vpc_id = aws_vpc.assignement_vpc.id

  tags = merge(var.tags, {
    Name = format("%s-assignement_igw", var.tags["id"])
    }
  )
}

resource "aws_eip" "assignement_eip" {
  count = length(var.availability_zone)
  vpc   = true
  tags = merge(var.tags, {
    Name = format("%s-assignement_eip-${count.index}", var.tags["id"])
    }
  )
  depends_on = [aws_internet_gateway.assignement_igw]
}

resource "aws_nat_gateway" "assignement_nat_gateway" {
  count         = length(var.availability_zone)
  allocation_id = element(aws_eip.assignement_eip.*.id, count.index)
  subnet_id     = element(aws_subnet.assignement_public_subnet.*.id, count.index)

  tags = merge(var.tags, {
    Name = format("%s-assignement_nat_gateway-${count.index}", var.tags["id"])
    }
  )

  depends_on = [aws_internet_gateway.assignement_igw]
}

resource "aws_route_table" "assignement_rt_public" {
  vpc_id = aws_vpc.assignement_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.assignement_igw.id
  }

  tags = merge(var.tags, {
    Name = format("%s-assignement_public_rt", var.tags["id"])
    }
  )
}
resource "aws_route_table_association" "assignement_rt_associate" {
  count          = length(var.availability_zone)
  subnet_id      = element(aws_subnet.assignement_public_subnet.*.id, count.index)
  route_table_id = aws_route_table.assignement_rt_public.id
}

resource "aws_route_table" "assignement_rt_private" {
  count  = length(var.availability_zone)
  vpc_id = aws_vpc.assignement_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.assignement_nat_gateway.*.id, count.index)
  }

  tags = merge(var.tags, {
    Name = format("%s-assignement_private_rt-${count.index}", var.tags["id"])
    }
  )
}
resource "aws_route_table_association" "assignement_private_rt_associate" {
  count          = length(var.availability_zone)
  subnet_id      = element(aws_subnet.assignement_private_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.assignement_rt_private.*.id, count.index)
}