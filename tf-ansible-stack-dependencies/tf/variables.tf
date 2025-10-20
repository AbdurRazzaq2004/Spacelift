variable "public_key" {
  description = "Path to the SSH public key file to upload to AWS (e.g. ~/.ssh/id_rsa.pub). Provide via -var or a tfvars file."
  type        = string
  default     = ""

  validation {
    condition     = length(var.public_key) > 0
    error_message = "You must set 'public_key' to the path of your public key file (e.g. ~/.ssh/id_rsa.pub)"
  }
}

variable "aws_region" {
  description = "AWS region to create resources in"
  type        = string
  default     = "eu-west-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 3
}

variable "instances_prefix" {
  description = "Prefix for EC2 instance Name tag"
  type        = string
  default     = "instance"
}
