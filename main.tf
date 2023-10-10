##################################################################################
# PROVIDERS
##################################################################################
# https://www.linuxbabe.com/ubuntu/install-lemp-stack-ubuntu-22-04-server-desktop
# https://www.linuxbabe.com/ubuntu/install-wordpress-ubuntu-22-04-nginx-mariadb-php8-1-lemp

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region   
}
provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_key
}
##################################################################################
# DATA SOURCES
##################################################################################
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # aws ec2 describe-images --image-ids ami-024e6efaf93d85776 --output json | jq '.Images[] | {Platform, OwnerId}'
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}
##################################################################################
# RESOURCES
##################################################################################
resource "aws_vpc" "main" {
  cidr_block           = var.cidr_vpc
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.cidr_subnet
}

resource "aws_security_group" "main" {
  name   = "dlg-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

resource "aws_instance" "main" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  associate_public_ip_address = true
  key_name                    = var.ssh_key
  security_groups             = ["${aws_security_group.main.id}"]
  subnet_id                   = aws_subnet.main.id
  user_data = templatefile("./config/userdata", {
    domain = var.proxy_service_address
    email  = var.cloudflare_email
  })
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  root_block_device {
    encrypted = true
  }
  # Prevents resource being recreated for minor versions of AMI 
  lifecycle {
    ignore_changes = [ami, user_data]
  }
  tags = {
    Name = "node-name-here"
  }
}

resource "cloudflare_record" "lemp" {
  zone_id = var.cloudflare_zone_id
  name    = var.proxy_service_address
  value   = aws_instance.main.public_ip
  type    = "A"
  proxied = false
  ttl     = 60
}
##################################################################################
# OUTPUT
##################################################################################
output "aws_instance_public_dns" {
  value = aws_instance.main.public_dns
}
output "aws_instance_public_ip" {
  value = aws_instance.main.public_ip
}
##################################################################################
