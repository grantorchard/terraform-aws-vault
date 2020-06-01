data terraform_remote_state "this" {
  backend = "remote"

  config = {
    organization = "grantorchard"
    workspaces = {
      name = "terraform-aws-core"
    }
  }
}

locals {
  public_subnets = data.terraform_remote_state.this.outputs.public_subnets
  security_group_outbound = data.terraform_remote_state.this.outputs.security_group_outbound
  security_group_ssh = data.terraform_remote_state.this.outputs.security_group_ssh
  vpc_id = data.terraform_remote_state.this.outputs.vpc_id
}

data aws_route53_zone "this" {
  name         = "go.hashidemos.io"
  private_zone = false
}

data aws_ami "ubuntu" {
  most_recent = true

  filter {
    name = "tag:application"
    values = ["vault-1.4.0"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["753646501470"] # HashiCorp account
}

module "vault" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "2.13.0"

  name = var.hostname
  instance_count = 1

  user_data_base64 = base64gzip(data.template_file.userdata.rendered)

  ami = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name = var.key_name
  iam_instance_profile = aws_iam_instance_profile.this.name

  monitoring = true
  vpc_security_group_ids = [
    local.security_group_outbound,
    local.security_group_ssh,
    module.security_group_vault.this_security_group_id
  ]

  subnet_id = local.public_subnets[0]
  tags = var.tags
}

resource aws_route53_record "this" {
  zone_id = data.aws_route53_zone.this.id
  name    = "${var.hostname}.${data.aws_route53_zone.this.name}"
  type    = "A"
  ttl     = "300"
  records = [module.vault.public_ip[0]]
}

module "security_group_vault" {
  source  = "terraform-aws-modules/security-group/aws"

  name        = "vault-http"
  description = "vault http access"
  vpc_id      = local.vpc_id

  ingress_cidr_blocks = [
    "220.235.156.186/32",
    "10.0.0.0/16"
    ]
  rules = { "vault":[ 8200, 8200, "tcp", "HashiCorp Vault traffic"]}
  tags = var.tags
}

data aws_iam_policy_document "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data aws_iam_policy_document "this" {
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "autoscaling:DescribeAutoScalingGroups",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey"
    ]

    resources = ["*"]
  }
}


resource aws_iam_instance_profile "this" {
  name_prefix = var.hostname
  path        = var.instance_profile_path
  role        = aws_iam_role.this.name
}

resource aws_iam_role "this" {
  name_prefix        = var.hostname
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource aws_iam_role_policy "this" {
  name   = var.hostname
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.this.json
}


resource aws_kms_key "this" {
  description             = "Vault unseal key"
  deletion_window_in_days = 10
  tags = var.tags
}

