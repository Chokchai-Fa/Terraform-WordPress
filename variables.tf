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

variable "database_name" {
    description = "Value of database name"
    type = string
    default = "wordpress"
}

variable "database_user" {
    description = "Value of database user"
    type = string
    default = "root"
}

variable "database_pass" {
    description = "Value of database password"
    type = string
    default = "Phukao98765"
}

variable "admin_user" {
    description = "Value of wordpress admin username"
    type = string
    default = "admin"
}

variable "admin_pass" {
    description = "Value of wordpress admin username"
    type = string
    default = "1234"
}
