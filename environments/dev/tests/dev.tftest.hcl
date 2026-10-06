# Plan-level checks for the dev root. Provider and data sources are mocked, so
# this runs offline; it proves the committed dev settings wire into the module.

mock_provider "aws" {
  override_data {
    target = data.aws_vpc.this
    values = { id = "vpc-0d0e0f1a2b3c4d5e6" }
  }

  override_data {
    target = data.aws_subnets.private
    values = { ids = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"] }
  }

  override_data {
    target = data.aws_ami.app
    values = { id = "ami-0123456789abcdef0" }
  }
}

run "dev_is_a_single_small_instance" {
  command = plan

  assert {
    condition     = length(output.instance_subnet_ids) == 1
    error_message = "dev should run exactly one instance."
  }

  assert {
    condition     = output.instance_subnet_ids[0] == "subnet-0aaaaaaaaaaaaaaa1"
    error_message = "dev instance should land in the first private subnet."
  }
}
