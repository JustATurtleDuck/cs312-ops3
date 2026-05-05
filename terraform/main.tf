provider "aws" {
  region = var.aws_region
}

# Networking (yay): Grab default VPC for public IP placement
data "aws_vpc" "default" {
  default = true
}

# OS: fetch latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS Account ID
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Security Group: Allow Admin SSH and Player Traffic
resource "aws_security_group" "minecraft_sg" {
  name        = "minecraft-sg-ops3"
  description = "Allow SSH and TCP 25565 for Minecraft"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 25565
    to_port     = 25565
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

# The EC2 Instance
resource "aws_instance" "minecraft_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium" # Minimum specs for Minecraft Java I think?
  key_name      = var.key_name

  # grants S3 and ECR access without putting AWS Keys on the disk
  iam_instance_profile = "LabInstanceProfile"

  vpc_security_group_ids = [aws_security_group.minecraft_sg.id]

  tags = {
    Name = "obsidian-minecraft-automated"
  }
}