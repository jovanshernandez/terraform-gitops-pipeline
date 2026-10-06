# Unit tests for the app-host module. The AWS provider is mocked, so these run
# offline with no credentials: they check what Terraform would send to AWS.

mock_provider "aws" {}

variables {
  name                = "orders-api"
  environment         = "dev"
  vpc_id              = "vpc-0a1b2c3d4e5f60718"
  subnet_ids          = ["subnet-0a1b2c3d4e5f60718", "subnet-1a2b3c4d5e6f70819"]
  ami_id              = "ami-0123456789abcdef0"
  instance_count      = 3
  ingress_cidr_blocks = ["10.20.0.0/16", "192.168.10.0/24"]
}

run "instances_require_imdsv2" {
  command = plan

  assert {
    condition     = alltrue([for i in aws_instance.this : i.metadata_options[0].http_tokens == "required"])
    error_message = "Every instance must require IMDSv2 session tokens."
  }

  assert {
    condition     = alltrue([for i in aws_instance.this : i.metadata_options[0].http_put_response_hop_limit == 1])
    error_message = "IMDS hop limit must be 1 so containers cannot reach instance credentials."
  }
}

run "root_volumes_are_encrypted_gp3" {
  command = plan

  assert {
    condition     = alltrue([for i in aws_instance.this : i.root_block_device[0].encrypted && i.root_block_device[0].volume_type == "gp3"])
    error_message = "Root volumes must be encrypted gp3."
  }
}

run "access_is_ssm_not_ssh" {
  command = plan

  assert {
    condition     = alltrue([for r in aws_vpc_security_group_ingress_rule.app : r.from_port != 22 && r.to_port != 22])
    error_message = "No ingress rule may open port 22."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.ssm_core.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "The instance role must carry the Session Manager core policy."
  }

  assert {
    condition     = alltrue([for i in aws_instance.this : i.iam_instance_profile == "orders-api-dev-ec2"])
    error_message = "Every instance must use the module's instance profile."
  }
}

run "instances_are_private_and_spread_across_subnets" {
  command = plan

  assert {
    condition     = alltrue([for i in aws_instance.this : i.associate_public_ip_address == false])
    error_message = "Instances must not get public IP addresses."
  }

  assert {
    condition     = [for i in aws_instance.this : i.subnet_id] == ["subnet-0a1b2c3d4e5f60718", "subnet-1a2b3c4d5e6f70819", "subnet-0a1b2c3d4e5f60718"]
    error_message = "Instances must be placed round-robin across the given subnets."
  }
}

run "one_ingress_rule_per_private_cidr" {
  command = plan

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.app) == 2
    error_message = "Expected one ingress rule per CIDR."
  }

  assert {
    condition     = alltrue([for r in aws_vpc_security_group_ingress_rule.app : r.from_port == 8080 && r.ip_protocol == "tcp"])
    error_message = "Ingress must be limited to the app port over TCP."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.https.from_port == 443 && aws_vpc_security_group_egress_rule.https.to_port == 443
    error_message = "Egress must be limited to HTTPS."
  }
}

run "accepts_every_rfc1918_range" {
  command = plan

  variables {
    ingress_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.app) == 3
    error_message = "All three RFC 1918 ranges should be accepted."
  }
}

run "rejects_public_ingress" {
  command = plan

  variables {
    ingress_cidr_blocks = ["0.0.0.0/0"]
  }

  expect_failures = [var.ingress_cidr_blocks]
}

run "rejects_lookalike_private_range" {
  command = plan

  variables {
    ingress_cidr_blocks = ["10.20.0.0/16", "172.32.0.0/16"]
  }

  expect_failures = [var.ingress_cidr_blocks]
}

run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "staging"
  }

  expect_failures = [var.environment]
}

run "rejects_oversized_fleet" {
  command = plan

  variables {
    instance_count = 20
  }

  expect_failures = [var.instance_count]
}

run "prod_rejects_single_subnet" {
  command = plan

  variables {
    environment    = "prod"
    instance_count = 2
    subnet_ids     = ["subnet-0a1b2c3d4e5f60718"]
  }

  expect_failures = [aws_instance.this]
}

run "ssm_session_commands_follow_instance_ids" {
  # apply against the mock provider so instance IDs are known values.
  command = apply

  assert {
    condition     = length(output.ssm_session_commands) == 3
    error_message = "Expected one Session Manager command per instance."
  }

  assert {
    condition     = output.ssm_session_commands[0] == "aws ssm start-session --target ${aws_instance.this[0].id}"
    error_message = "Session Manager command must target the instance ID."
  }
}
