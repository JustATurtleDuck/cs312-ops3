variable "aws_region" {
  description = "The AWS region to deploy into"
  default     = "us-east-1"
  type        = string
}

variable "key_name" {
  description = "The name of AWS SSH Key pair"
  default     = "cs312-key" 
  type        = string
}
