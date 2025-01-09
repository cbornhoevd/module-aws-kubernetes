provider "aws" {
  region = var.aws_region
}

locals {
  cluster_name = "${var.cluster_name}-${var.env_name}"
}

# Cluster Access Management Policy
# * IAM Role to allow EKS service to manage other AWS services
resource "aws_iam_role" "jupiter-cluster" {
  name = local.cluster_name

  assume_role_policy = <<POLICY {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "eks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  POLICY
}

resource "aws_iam_role_policy_attachment" "jupiter-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = aws_iam_role.jupiter-cluster.name
}

# EC2 Security Group to allow networking traffic with EKS cluster
resource "aws_security_group" "jupiter-cluster" {
  name = local.cluster_name
  description = "Cluster communication with worker nodes"
  vpc_id = var.vpc_id

  egress {
    description = "Allows unrestricted outbound traffic"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self = true
  }

  tags = {
    Name = "jupiter"
  }
}

# * EKS Cluster definition