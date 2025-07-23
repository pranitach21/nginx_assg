provider "aws" {
  region  = var.aws_region
  profile = "bits-id-aws"
}

variable "aws_region" {
  default = "ap-south-1"
}

variable "vip_private_ip" {
  default = "172.31.32.250"
}

# Get default VPC and subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group
resource "aws_security_group" "nginx_sg" {
  name        = "nginx-ha-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
}
 resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = "nginx-ha-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/nginx-ha.pem"
  file_permission = "0600"
}
 
  resource "aws_iam_role" "ec2_role" {
  name = "nginx-ha-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "eip_control" {
  name = "eip-control"
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "ec2:AssociateAddress",
        "ec2:DisassociateAddress",
        "ec2:DescribeAddresses",
        "ec2:DescribeInstances"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "nginx-ha-profile"
  role = aws_iam_role.ec2_role.name
}


data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.*-x86_64-gp2"]
  }
}

# Elastic IP for VIP
resource "aws_eip" "vip" {
  domain = "vpc"
}

# Backend nodes
resource "aws_instance" "app_node_a" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = data.aws_subnets.default.ids[0]
  key_name               = aws_key_pair.main.key_name
  associate_public_ip_address = true
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.nginx_sg.id]
  user_data              = file("user_data_node_a.sh")

  tags = { Name = "App-Node-A" }
}

resource "aws_instance" "app_node_b" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = data.aws_subnets.default.ids[1]
  key_name               = aws_key_pair.main.key_name
  associate_public_ip_address = true
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.nginx_sg.id]
  user_data              = file("user_data_node_b.sh")

  tags = { Name = "App-Node-B" }
}

# Load Balancer nodes
resource "aws_instance" "lb_master" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = data.aws_subnets.default.ids[0]
  associate_public_ip_address = true
  key_name               = aws_key_pair.main.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.nginx_sg.id]

  tags = { Name = "LB-Master" }
}

resource "aws_instance" "lb_backup" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = data.aws_subnets.default.ids[1]
  associate_public_ip_address = true
  key_name               = aws_key_pair.main.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.nginx_sg.id]

  tags = { Name = "LB-Backup" }
}


resource "null_resource" "setup_keepalived_master" {
  provisioner "file" {
    content = templatefile("${path.module}/nginx_lb_keepalived.sh.tpl", {
      backend_1       = aws_instance.app_node_a.private_ip
      backend_2       = aws_instance.app_node_b.private_ip
      vip             = var.vip_private_ip
      interface       = "eth0"
      state           = "MASTER"
      priority        = 150
      peer_ip         = aws_instance.lb_backup.private_ip
      eip_id          = aws_eip.vip.id
      region          = var.aws_region
      master_ip       = aws_instance.lb_master.private_ip
      private_ip      = aws_instance.lb_master.private_ip
        })
    destination = "/tmp/nginx_lb_keepalived.sh"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.lb_master.public_ip
      private_key = file(local_file.private_key.filename)
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/nginx_lb_keepalived.sh",
      "sudo bash /tmp/nginx_lb_keepalived.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.lb_master.public_ip
      private_key = file(local_file.private_key.filename)
    }
  }
}

# Repeat similar block for lb_backup with STATE=BACKUP, PRIORITY=100
resource "null_resource" "setup_keepalived_backup" {
  provisioner "file" {
    content = templatefile("${path.module}/nginx_lb_keepalived.sh.tpl", {
      backend_1       = aws_instance.app_node_a.private_ip
      backend_2       = aws_instance.app_node_b.private_ip
      vip             = var.vip_private_ip
      interface       = "eth0"
      state           = "BACKUP"
      priority        = 100
      peer_ip         = aws_instance.lb_master.private_ip 
      eip_id          = aws_eip.vip.id
      region          = var.aws_region
      master_ip       = aws_instance.lb_master.private_ip
      private_ip      = aws_instance.lb_backup.private_ip 
    })
    destination = "/tmp/nginx_lb_keepalived.sh"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.lb_backup.public_ip
      private_key = file(local_file.private_key.filename)
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/nginx_lb_keepalived.sh",
      "sudo bash /tmp/nginx_lb_keepalived.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        = aws_instance.lb_backup.public_ip
      private_key = file(local_file.private_key.filename)
    }
  }
}

output "lb_master_public_ip" {
  value = aws_instance.lb_master.public_ip
}

output "lb_backup_public_ip" {
  value = aws_instance.lb_backup.public_ip
}

output "vip_public_ip" {
  value = aws_eip.vip.public_ip
}

output "app_node_a_public_ip" {
  value = aws_instance.app_node_a.public_ip
}

output "app_node_b_public_ip" {
  value = aws_instance.app_node_b.public_ip
}
