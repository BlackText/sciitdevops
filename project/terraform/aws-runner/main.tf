# Declare the AWS region variable directly within the main.tf
variable "aws_region" {
  description = "AWS region for the infrastructure"
  type        = string
  default     = "us-east-1"  # Change this to your desired region
}

# Provider configuration
provider "aws" {
  region = var.aws_region
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.0"

  name             = "python-vpc"
  cidr             = "10.0.0.0/16"
  azs              = data.aws_availability_zones.available.names  # Dynamically get AZs based on the region
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets   = ["10.0.3.0/24", "10.0.4.0/24"]
  enable_nat_gateway = true
}

# Data source to dynamically fetch the latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical's official AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
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

# Security Group for the Python instance
resource "aws_security_group" "python_sg" {
  name        = "python-security-group"
  description = "Allow Python, HTTP, and SSH traffic"
  vpc_id      = module.vpc.vpc_id

  # Allow HTTP traffic on port 8080
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH traffic on port 22
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance for Python setup
resource "aws_instance" "python_vm" {
  ami           = data.aws_ami.ubuntu.id  # Use the latest Ubuntu 22.04 AMI
  instance_type = "t3.medium"
  subnet_id     = module.vpc.public_subnets[0]

  # Associate a public IP
  associate_public_ip_address = true

  # Use vpc_security_group_ids instead of security_groups
  vpc_security_group_ids = [aws_security_group.python_sg.id]

  key_name = "aws"  # Replace this with the actual key pair name

  tags = {
    Name = "python-server"
  }

  # Ensure that the EC2 instance is fully initialized before running remote-exec
  depends_on = [aws_security_group.python_sg]

  # Install Python on the EC2 instance using a shell script
  provisioner "remote-exec" {
    inline = [
      "sleep 60",  # Wait for 60 seconds to ensure the EC2 instance is initialized
      "sudo ufw disable",  # Disable UFW for testing purposes
      "sudo apt update -y",
      "sudo apt install -y python3 python3-pip",
      "sudo apt install -y python3-venv",
      "python3 --version",
      "sudo ufw allow 22",  # Ensure port 22 is allowed
      "sudo ufw allow 8080",  # Ensure port 8080 is open in UFW firewall
      "sudo ufw enable"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("./aws.pem")  # Path to your private key
      host        = self.public_ip
    }
  }
}

 Output Instance Public IP
output "python_vm_public_ip" {
  description = "Public IP of the Python server"
  value       = aws_instance.python_vm.public_ip
}

# Data source to fetch availability zones dynamically
data "aws_availability_zones" "available" {}
