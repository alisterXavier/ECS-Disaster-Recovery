data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
variable "region" {
  type = string
}
locals {
  public_subnets = [
    {
      az   = "us-east-1a",
      cidr = "10.0.8.0/23"
    },
    {
      az   = "us-east-1b",
      cidr = "10.0.10.0/23"
    }
  ]

  private_subnets = [
    {
      az   = "us-east-1a",
      cidr = "10.0.0.0/22"
    },
    {
      az   = "us-east-1b",
      cidr = "10.0.4.0/22"
    }
  ]

  domain_name = "851725578224.realhandsonlabs.net"
  zone_id     = "Z00073912TYAIVX754YTN"
}
