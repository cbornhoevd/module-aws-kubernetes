provider "aws" {
  region = var.aws_region
}

locals {
  cluster_name = "${var.cluster_name}-${var.env_name}"
}

# Cluster Role
resource "aws_iam_role" "jupiter-cluster" {
  name = local.cluster_name

  assume_role_policy = <<POLICY
{
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

# Cluster Policy
resource "aws_iam_role_policy_attachment" "jupiter-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.jupiter-cluster.name
}

# EC2 Security Group to allow networking traffic with EKS cluster
resource "aws_security_group" "jupiter-cluster" {
  name        = local.cluster_name
  description = "Cluster communication with worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    description = "Inbound traffic from within the security group"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  egress {
    description = "Allows unrestricted outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  tags = {
    Name = "jupiter"
  }
}

# EKS Cluster Definition
resource "aws_eks_cluster" "jupiter" {
  name     = local.cluster_name
  role_arn = aws_iam_role.jupiter-cluster.arn

  vpc_config {
    security_group_ids = [aws_security_group.jupiter-cluster.id]
    subnet_ids         = var.cluster_subnet_ids
  }

  depends_on = [aws_iam_role_policy_attachment.jupiter-cluster-AmazonEKSClusterPolicy]
}

# Node Role
resource "aws_iam_role" "jupiter-node" {
  name = "${local.cluster_name}.node"

  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
     }
   ]
}
POLICY
}

# Node Policy
resource "aws_iam_role_policy_attachment" "jupiter-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.jupiter-node.name
}

resource "aws_iam_role_policy_attachment" "jupiter-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.jupiter-node.name
}

resource "aws_iam_role_policy_attachment" "jupiter-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.jupiter-node.name
}

# Node Group Definition
resource "aws_eks_node_group" "jupiter-node-group" {
  cluster_name    = aws_eks_cluster.jupiter.name
  node_group_name = "jupiter"
  node_role_arn   = aws_iam_role.jupiter-node.arn
  subnet_ids      = var.nodegroup_subnet_ids

  scaling_config {
    desired_size = var.nodegroup_desired_size
    max_size     = var.nodegroup_max_size
    min_size     = var.nodegroup_min_size
  }

  disk_size      = var.nodegroup_disk_size
  instance_types = var.nodegroup_instance_types

  depends_on = [
    aws_iam_role_policy_attachment.jupiter-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.jupiter-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.jupiter-node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

# Create kubeconfig file based on EKS Cluster Definition
resource "local_file" "kubeconfig" {
  content  = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${aws_eks_cluster.jupiter.certificate_authority.0.data}
    server: ${aws_eks_cluster.jupiter.endpoint}
  name: ${aws_eks_cluster.jupiter.arn}
contexts:
- context:
    cluster: ${aws_eks_cluster.jupiter.arn}
    user: ${aws_eks_cluster.jupiter.arn}
  name: ${aws_eks_cluster.jupiter.arn}
current-context: ${aws_eks_cluster.jupiter.arn}
kind: Config
preferences: {}
users:
- name: ${aws_eks_cluster.jupiter.arn}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${aws_eks_cluster.jupiter.name}"
    KUBECONFIG
  filename = "kubeconfig"
}
