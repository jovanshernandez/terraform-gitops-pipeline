locals {
  name = "${var.name}-${var.environment}"

  # AWS managed policy that lets the SSM agent register the instance, so operators
  # get a shell through Session Manager instead of SSH keys and port 22.
  ssm_core_policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# -----------------------------------------------------------------------------
# Instance identity: an IAM role for Session Manager, no SSH key pair.
# -----------------------------------------------------------------------------

resource "aws_iam_role" "this" {
  name        = "${local.name}-ec2"
  description = "Instance role for ${local.name}; Session Manager access only."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.this.name
  policy_arn = local.ssm_core_policy_arn
}

resource "aws_iam_instance_profile" "this" {
  name = "${local.name}-ec2"
  role = aws_iam_role.this.name
  tags = var.tags
}

# -----------------------------------------------------------------------------
# Network access: the app port from private ranges only, HTTPS out for SSM and
# package repositories. No inline rules, so each rule is its own reviewable
# resource in the plan.
# -----------------------------------------------------------------------------

resource "aws_security_group" "this" {
  name        = "${local.name}-app"
  description = "App traffic for ${local.name} from private ranges; no SSH."
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${local.name}-app" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  for_each = toset(var.ingress_cidr_blocks)

  security_group_id = aws_security_group.this.id
  description       = "App port from ${each.value}"
  ip_protocol       = "tcp"
  from_port         = var.app_port
  to_port           = var.app_port
  cidr_ipv4         = each.value
  tags              = var.tags
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.this.id
  description       = "HTTPS out for SSM endpoints and package repositories"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
  tags              = var.tags
}

# -----------------------------------------------------------------------------
# Instances: private subnets, IMDSv2 only, encrypted gp3 root volume.
# -----------------------------------------------------------------------------

resource "aws_instance" "this" {
  count = var.instance_count

  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = false
  monitoring                  = true
  ebs_optimized               = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    encrypted             = true
    kms_key_id            = var.kms_key_id
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  tags = merge(var.tags, { Name = "${local.name}-${count.index + 1}" })

  lifecycle {
    precondition {
      condition     = var.environment != "prod" || (var.instance_count >= 2 && length(distinct(var.subnet_ids)) >= 2)
      error_message = "prod needs at least two instances spread across at least two subnets."
    }
  }
}
