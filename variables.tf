variable "ami" {
 description = "Value of AMI EC2 Ubuntu-22.04 LTS (HVM)"
 type = string
 default = "ami-0123c9b6bfb7eb962"
}

variable "region" {
 description = "Value of AWS Region"
 type = string
 default = "ap-southeast-1"
}

variable "availability_zone" {
 description = "Value of avalibility zone"
 type = string
 default = "ap-southeast-1a"
}