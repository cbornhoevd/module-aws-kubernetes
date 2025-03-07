variable "aws_region" {
  description = "AWS region ID for deployment (e.g. eu-west-2)"
  type        = string
  default     = "us-east-1"
}

variable "env_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "jupiter_namespace" {
  type    = string
  default = "jupiter"
}

variable "vpc_id" {
  type = string
}

variable "cluster_subnet_ids" {
  type = list(string)
}

variable "nodegroup_subnet_ids" {
  type = list(string)
}

variable "nodegroup_desired_size" {
  type    = number
  default = 1
}

variable "nodegroup_min_size" {
  type    = number
  default = 1
}

variable "nodegroup_max_size" {
  type    = number
  default = 3
}

variable "nodegroup_disk_size" {
  type = string
}

variable "nodegroup_instance_types" {
  type = list(string)
}
