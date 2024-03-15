# main.tf

terraform {
 required_providers {
 aws = {
    source = "hashicorp/aws"
    version = "~> 5.39"
    }
 }
 required_version = ">= 1.2.0"
}

# Configure the AWS provider
provider "aws" {
  region = var.region
  profile = "chokchai"
}

# Create a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"  # CIDR Block

  # Enable DNS support and hostname assignment
  enable_dns_support = true
  enable_dns_hostnames = true
}

# Create an Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

# Create a public subnet in the VPC
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block             = "10.0.1.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true            # Allow instances in this subnet to have public IPs
}

# Create a private subnet in the VPC
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block             = "10.0.10.0/24"  
  availability_zone       = var.availability_zone
}

# Create a Route Table for the public subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id
}

# Create a default route pointing to the Internet Gateway
resource "aws_route" "public_route_igw" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_igw.id
}

# Associate the public subnet with the public route table
resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# Create a NAT gateway
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
}

# Create a Route Table for the private subnet
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id
}

# Create a default route pointing to the NAT Gateway in the private route table
resource "aws_route" "private_route_nat" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id             = aws_nat_gateway.nat_gateway.id
}

# Associate the private subnet with the private route table
resource "aws_route_table_association" "private_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_security_group" "wordpress_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "mariadb_sg" {
  vpc_id = aws_vpc.my_vpc.id

  # Allow ICMP (ping) traffic
  ingress {
    from_port   = -1  # -1 means any port
    to_port     = -1  # -1 means any port
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
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

## EC2 in private subnet (mairadb)
resource "aws_instance" "mariadb_instance" {
  ami           = var.ami
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.mariadb_sg.id]
  key_name = "chokchai-chula"
  private_ip   = "10.0.10.74"
  user_data     = <<-EOF
                #!/bin/bash
                sudo apt-get update
                sudo apt-get install -y mariadb-server
                sudo sh -c 'echo "[mysqld]" >> /etc/mysql/my.cnf'
                sudo sh -c 'echo "bind-address = 0.0.0.0" >> /etc/mysql/my.cnf'
                sudo mysql -uroot -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'Phukao98765';"
                sudo mysql -uroot -p'Phukao98765' -e "CREATE DATABASE wordpress;"
                sudo mysql -uroot -p'Phukao98765' -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'Phukao98765' WITH GRANT OPTION;"
                sudo mysql -uroot -p'Phukao98765' -e "FLUSH PRIVILEGES;"
                sudo systemctl restart mariadb
                EOF

  tags = {
    Name = "MariaDBInstance"
  }
}

output "mariadb_instance_ip" {
  value = aws_instance.mariadb_instance.private_ip
}


## EC2 in public subnet (wordpress)
resource "aws_instance" "wordpress_instance" {
  ami           = var.ami
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name = "chokchai-chula"
  vpc_security_group_ids = [aws_security_group.wordpress_sg.id]

  depends_on = [aws_instance.mariadb_instance]

  
  provisioner "remote-exec" {
    inline= [
              <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y software-properties-common
              sudo apt-get update
              sudo apt-get install -y php8.1 php8.1-cli php8.1-mysql php8.1-gd php8.1-xml php8.1-mbstring php8.1-curl php8.1-zip
              sudo apt-get install -y apache2 mysql-server
              sudo apt-get install -y wget
              curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
              chmod +x wp-cli.phar
              sudo mv wp-cli.phar /usr/local/bin/wp
              cd /var/www/html
              sudo wget https://wordpress.org/latest.tar.gz
              sudo tar -xzvf latest.tar.gz
              sudo chown -R www-data:www-data wordpress
              sudo rm latest.tar.gz
              cd wordpress
              sudo cp wp-config-sample.php wp-config.php
              sudo sed -i 's/database_name_here/${var.database_name}/g' wp-config.php
              sudo sed -i 's/username_here/${var.database_user}/g' wp-config.php
              sudo sed -i 's/password_here/${var.database_pass}/g' wp-config.php
              sudo sed -i "s/localhost/${aws_instance.mariadb_instance.private_ip}/g" wp-config.php
              sudo mv /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.bak
              sudo touch /etc/apache2/sites-available/000-default.conf
              echo "<VirtualHost *:80>
                  ServerAdmin webmaster@localhost
                  DocumentRoot /var/www/html/wordpress
                  ErrorLog /var/log/apache2/error.log
                  CustomLog /var/log/apache2/access.log combined
              </VirtualHost>" | sudo tee /etc/apache2/sites-available/000-default.conf
              sudo a2enmod rewrite
              sudo systemctl restart apache2
              sudo systemctl restart mysql
              wp core install --url=${aws_instance.wordpress_instance.public_ip}  --title="Chokchai Site" --admin_user=${var.admin_user} --admin_password=${var.admin_pass} --admin_email="6572015021@student.chula.ac.th" --skip-email --allow-root --path=/var/www/html/wordpress
              wp site switch-language en_US --allow-root --path=/var/www/html/wordpress
              EOF
              ]
  connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/chokchai-chula.pem")
      host        = self.public_ip
    }

  }

  tags = {
    Name = "WordpressInstance"
  }
}

output "wordpress_instance_ip" {
  value = aws_instance.wordpress_instance.public_ip
}