module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.15.0"

  name = "${local.env}-vpc"
  # BEST PRACTICE: Use a standard RFC 1918 private IP range.
  cidr = "10.0.0.0/16"

  azs             = ["${local.region}a", "${local.region}b"]
  
  # CORRECTED: Private subnets are now within the main VPC CIDR block.
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  
  # CORRECTED: Public subnets are also within the main VPC CIDR block.
  # Using a higher number range like 100+ helps distinguish them.
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # This configuration is correct for allowing private subnets to reach the internet.
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false # Set to 'true' for production for high availability

  # These DNS settings are correct and required.
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Your tags are well-configured for Kubernetes and Karpenter.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                  = "1"
    "kubernetes.io/cluster/${local.eks_name}" = "shared"
    subnet_type                               = "public"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"         = "1"
    "kubernetes.io/cluster/${local.eks_name}" = "shared"
    "karpenter.sh/discovery"                  = "${local.eks_name}-kpt"
    subnet_type                               = "private"
  }

  # These are good defaults to manage the VPC cleanly.
  manage_default_network_acl    = true
  manage_default_route_table    = true
  manage_default_security_group = true

  tags = {
    Terraform   = "true"
    Environment = local.env
  }
}