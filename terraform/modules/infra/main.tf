# @req: REQ-86

# ── AMI ─────────────────────────────────────────────────────────────────────
# Owner 427812963091 is the official NixOS AMI account. NixOS is chosen for
# declarative host package management (Docker via virtualisation.docker.enable).
data "aws_ami" "nixos" {
  most_recent = true
  owners      = ["427812963091"]

  filter {
    name   = "name"
    values = ["nixos/*-x86_64-linux"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Network ──────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(var.tags, { Name = "a2t-mrv-vpc" })
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false
  tags                    = merge(var.tags, { Name = "a2t-mrv-subnet" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "a2t-mrv-igw" })
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, { Name = "a2t-mrv-rt" })
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# ── Security Group ───────────────────────────────────────────────────────────
resource "aws_security_group" "main" {
  name        = "a2t-mrv-sg"
  description = "SSH, HTTP, HTTPS inbound; all outbound."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "a2t-mrv-sg" })
}

# ── EC2 Instance ─────────────────────────────────────────────────────────────
resource "aws_instance" "main" {
  ami                    = data.aws_ami.nixos.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.main.id]

  # Root volume — OS only; data lives on the separate EBS volume.
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
  }

  tags = merge(var.tags, { Name = "a2t-mrv-vm" })
}

# ── Elastic IP ───────────────────────────────────────────────────────────────
resource "aws_eip" "main" {
  domain   = "vpc"
  instance = aws_instance.main.id
  tags     = merge(var.tags, { Name = "a2t-mrv-eip" })

  depends_on = [aws_internet_gateway.main]
}

# ── EBS Data Volume (Postgres data directory) ────────────────────────────────
resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.main.availability_zone
  size              = var.data_volume_size_gb
  type              = "gp3"
  tags              = merge(var.tags, { Name = "a2t-mrv-data" })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "data" {
  device_name  = "/dev/sdf"
  volume_id    = aws_ebs_volume.data.id
  instance_id  = aws_instance.main.id
  force_detach = false
}
