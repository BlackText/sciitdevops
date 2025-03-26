provider "aws" {
  region = var.aws_region
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.0"

  name = "k3s-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.3.0/24", "10.0.4.0/24"]
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

# Security Group for k3s VM
resource "aws_security_group" "k3s_sg" {
  name        = "k3s-security-group"
  description = "Allow SSH, k3s traffic, and Prometheus/Grafana ports"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 31327
    to_port     = 31327
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
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


# EC2 Instance for k3s with more physical storage (root block device size)
resource "aws_instance" "k3s_vm" {
  ami           = data.aws_ami.ubuntu.id  # Use the latest Ubuntu 22.04 AMI
  instance_type = "t3.medium"  # Instance type with standard memory configuration
  subnet_id     = module.vpc.public_subnets[0]

  # Associate a public IP
  associate_public_ip_address = true

  # Use vpc_security_group_ids instead of security_groups
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  key_name = "aws"  # Replace this with the actual key pair name

  tags = {
    Name = "k3s-server"
  }

  # provisioner "local-exec" {
  #   command = "sleep 90 && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ${self.public_ip}, -u ubuntu --private-key=./aws.pem install_k3s.yml -vv"
  # }

  # Modify root block device to have more physical storage (e.g., 100 GB)
  root_block_device {
    volume_size = 100  # Size in GB
    volume_type = "gp3"  # General Purpose SSD (optional)
  }
}

# Output Instance Public IP
output "k3s_vm_public_ip" {
  description = "Public IP of the k3s server"
  value       = aws_instance.k3s_vm.public_ip
}
