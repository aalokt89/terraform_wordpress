
# Retrieve the list of AZs in the current AWS region
data "aws_availability_zones" "available" {}

locals {
  name_prefix = "${var.app_name}-${var.environment}"
  azs         = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

# Create vpc, subnets, and route tables
#----------------------------------------------------

module "vpc" {
  source                  = "terraform-aws-modules/vpc/aws"
  version                 = "4.0.1"
  name                    = local.name_prefix
  cidr                    = var.vpc_cidr
  enable_dns_hostnames    = var.enable_dns_hostnames
  map_public_ip_on_launch = var.map_public_ip_on_launch

  azs = local.azs

  # Public subnets
  public_subnets = [for key, value in local.azs : cidrsubnet(local.vpc_cidr, var.public_newbits, key + var.public_newnum)]
  public_subnet_tags = {
    "Tier" = "Web"
  }

  # Private subnets
  private_subnets = [for key, value in local.azs : cidrsubnet(local.vpc_cidr, var.private_newbits, key + var.private_newnum)]
  private_subnet_tags = {
    "Tier" = "Database"
  }

  # NAT
  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = var.one_nat_gateway_per_az

}

# Auto scaling wordpress servers
#----------------------------------------------------
module "wordpress_asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "1.0.4"

  instance_name = "${var.app_name}-server"
  image_id      = var.ami
  instance_type = var.instance_type
  # security_groups = ["sg-12345678"]

  # Auto scaling group
  asg_name            = "${var.app_name}-asg"
  vpc_zone_identifier = [for subnet in module.vpc.public_subnets : subnet.id]
  # health_check_type         = "EC2"
  min_size = 2
  max_size = 4
}

