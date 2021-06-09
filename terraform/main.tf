provider "aws" {
  region = "us-west-2"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

#Bootstrap ansible
locals {
  user_data = <<EOF
#cloud-config
packages:
  - python3
  - python3-dev
  - python3-setuptools
EOF
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "minanode"
  description = "Mina node secgroup"
  vpc_id      = data.aws_vpc.default.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp"]
  egress_rules        = ["all-all"]

  ingress_with_cidr_blocks = [
    {
      from_port   = 8302
      to_port     = 8302
      protocol    = "tcp"
      description = "Mina Protocol"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}

module "ec2" {
  source = "terraform-aws-modules/ec2-instance/aws"

  instance_count = 1

  name                        = "minanode"
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "c5.2xlarge"
  key_name                    = "david"
  subnet_id                   = tolist(data.aws_subnet_ids.all.ids)[0]
  vpc_security_group_ids      = [module.security_group.security_group_id]
  associate_public_ip_address = true
  user_data_base64            = base64encode(local.user_data)
  tags = {
    "group" = "minanodes"
  }
}

output "public_ip" {
  value = module.ec2.public_ip
}

output "public_dns" {
  value = module.ec2.public_dns
}
