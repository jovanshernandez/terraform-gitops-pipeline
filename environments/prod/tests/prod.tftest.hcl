# Plan-level checks for the prod root. Provider and data sources are mocked, so
# this runs offline; it proves prod keeps its availability guarantees.

mock_provider "aws" {
  override_data {
    target = data.aws_vpc.this
    values = { id = "vpc-0d0e0f1a2b3c4d5e6" }
  }

  override_data {
    target = data.aws_subnets.private
    values = { ids = ["subnet-0bbbbbbbbbbbbbbb2", "subnet-0aaaaaaaaaaaaaaa1"] }
  }

  override_data {
    target = data.aws_ami.app
    values = { id = "ami-0123456789abcdef0" }
  }
}

run "prod_spreads_instances_across_subnets" {
  command = plan

  assert {
    condition     = length(output.instance_subnet_ids) >= 2
    error_message = "prod must run at least two instances."
  }

  assert {
    condition     = length(distinct(output.instance_subnet_ids)) >= 2
    error_message = "prod instances must be spread across at least two subnets."
  }

  assert {
    condition     = output.instance_subnet_ids == ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
    error_message = "Subnets should be sorted so placement is stable between plans."
  }
}
