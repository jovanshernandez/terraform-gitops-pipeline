# dev environment. Everything that differs between environments is in this file
# and is committed, so a change to dev is a reviewed pull request.

locals {
  service             = "quote-service"
  instance_type       = "t4g.micro"
  instance_count      = 1
  root_volume_size    = 20
  ingress_cidr_blocks = ["10.40.0.0/16"]

  # Pinned AMI name (Amazon Linux 2023, arm64). Bump it in a pull request so the
  # replacement shows up in the reviewed plan instead of drifting in silently.
  ami_name = "al2023-ami-2023.8.20250818.0-kernel-6.1-arm64"

  # The VPC and its subnets are owned by a separate network stack and found by tag.
  vpc_name = "platform-dev"
}

data "aws_vpc" "this" {
  tags = {
    Name = local.vpc_name
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }

  tags = {
    Tier = "private"
  }
}

data "aws_ami" "app" {
  owners = ["amazon"]

  filter {
    name   = "name"
    values = [local.ami_name]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

module "app" {
  source = "../../modules/app-host"

  name                = local.service
  environment         = "dev"
  vpc_id              = data.aws_vpc.this.id
  subnet_ids          = sort(data.aws_subnets.private.ids)
  ami_id              = data.aws_ami.app.id
  instance_type       = local.instance_type
  instance_count      = local.instance_count
  root_volume_size    = local.root_volume_size
  ingress_cidr_blocks = local.ingress_cidr_blocks

  tags = {
    Service = local.service
    Owner   = "platform"
  }
}
