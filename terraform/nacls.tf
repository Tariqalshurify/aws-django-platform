# ============================================================
# Network ACL: Public Subnets
# ============================================================
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  # Inbound: Allow HTTP
  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    from_port  = 80
    to_port    = 80
    cidr_block = "0.0.0.0/0"
  }

  # Inbound: Allow HTTPS
  ingress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    from_port  = 443
    to_port    = 443
    cidr_block = "0.0.0.0/0"
  }

  # Inbound: Allow ephemeral ports (return traffic)
  ingress {
    rule_no    = 120
    action     = "allow"
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }

  # Outbound: Allow HTTP
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    from_port  = 80
    to_port    = 80
    cidr_block = "0.0.0.0/0"
  }

  # Outbound: Allow HTTPS
  egress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    from_port  = 443
    to_port    = 443
    cidr_block = "0.0.0.0/0"
  }

  # Outbound: Allow app traffic to private subnets
  egress {
    rule_no    = 120
    action     = "allow"
    protocol   = "tcp"
    from_port  = 8000
    to_port    = 8000
    cidr_block = var.vpc_cidr
  }

  # Outbound: Allow ephemeral ports
  egress {
    rule_no    = 130
    action     = "allow"
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }

  tags = { Name = "${var.project_name}-public-nacl" }
}

# ============================================================
# Network ACL: Private Subnets (App + DB)
# ============================================================
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = concat(aws_subnet.private[*].id, aws_subnet.database[*].id)

  # Inbound: App traffic from ALB
  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    from_port  = 8000
    to_port    = 8000
    cidr_block = var.vpc_cidr
  }

  # Inbound: PostgreSQL from app subnets
  ingress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    from_port  = 5432
    to_port    = 5432
    cidr_block = var.vpc_cidr
  }

  # Inbound: Return traffic from internet (via NAT)
  ingress {
    rule_no    = 120
    action     = "allow"
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }

  # Outbound: Allow all
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    from_port  = 0
    to_port    = 0
    cidr_block = "0.0.0.0/0"
  }

  tags = { Name = "${var.project_name}-private-nacl" }
}
