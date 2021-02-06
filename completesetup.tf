provider "aws" {
  region = "us-east-1"
  access_key = "AKIAIIQG7NAEL2UGB26Q"
  secret_key = "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"
}

# 1. Create vpc

resource "aws_vpc" "dev-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    "Name" = "Dev"
  }
}

# 2. Create Internet Gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.dev-vpc.id

  tags = {
    Name = "Dev"
  }
}

# 3. Create Custom Route Table

resource "aws_route_table" "dev-route-table" {
  vpc_id = aws_vpc.dev-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
      }

  tags = {
    Name = "Dev"
  }
}

# 4. Create a subnet

resource "aws_subnet" "dev-subnet" {
  vpc_id     = aws_vpc.dev-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Dev"
  }
}

# 5. Associate subnet with a Route Table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.dev-subnet.id
  route_table_id = aws_route_table.dev-route-table.id
}

# 6. Create Security Group to allow port 22, 80, 443

resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow Web traffic"
  vpc_id      = aws_vpc.dev-vpc.id

  ingress {
    description = "https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. Create a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.dev-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

# 8. Assign an elastic IP to the network created in step 7

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}

# 9. Create Ubuntu server and install apache2 

resource "aws_instance" "dev" {
  ami = "ami-0885b1f6bd170450c"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo Your very First Web Server > /var/www/html/index.html'
                EOF
             
  tags = {
    "Name" = "ubuntu-dev-web"
  }
  
}