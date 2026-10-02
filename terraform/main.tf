terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "aniketh-terraform-state-bucket-001"
    key          = "project2-monitoring/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = "ap-south-1"
}

# Read Project 1's state to get its VPC/subnet/key details
data "terraform_remote_state" "project1" {
  backend = "s3"

  config = {
    bucket = "aniketh-terraform-state-bucket-001"
    key    = "stage2-vpc/terraform.tfstate"
    region = "ap-south-1"
  }
}

variable "my_ip" {
  description = "Your current public IP, for SSH access via bastion"
  type        = string
}

resource "aws_security_group" "monitoring_sg" {
  name        = "monitoring-sg"
  description = "Monitoring server - SSH from bastion, metrics scraping"
  vpc_id      = data.terraform_remote_state.project1.outputs.vpc_id

  ingress {
    description     = "SSH from bastion only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.project1.outputs.bastion_sg_id]
  }

  ingress {
    description = "Grafana - accessed via SSH tunnel only, not public"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "monitoring-sg"
  }
}

data "aws_ami" "rhel" {
  most_recent = true
  owners      = ["309956199498"]

  filter {
    name   = "name"
    values = ["RHEL-9*HVM*x86_64*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.rhel.id
  instance_type          = "t3.small"
  subnet_id              = data.terraform_remote_state.project1.outputs.private_subnet_id
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]
  key_name               = data.terraform_remote_state.project1.outputs.project1_key_name

  tags = {
    Name = "monitoring-server"
  }
}

output "monitoring_private_ip" {
  value = aws_instance.monitoring.private_ip
}

output "monitoring_instance_id" {
  value = aws_instance.monitoring.id
}