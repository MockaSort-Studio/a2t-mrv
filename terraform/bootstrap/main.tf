locals {
  region     = var.aws_region
  account_id = var.account_id
}

# ── CI IAM User ───────────────────────────────────────────────────────────────
# Applied once by a human with admin credentials before CI is wired up.
# After applying, create the access key manually in the AWS console and add
# AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY to GitHub Actions secrets.
resource "aws_iam_user" "ci" {
  name = "a2t-mrv-terraform-ci"
  tags = { Project = "a2t-mrv", ManagedBy = "terraform-bootstrap" }
}

# ── CI IAM Policy ─────────────────────────────────────────────────────────────
resource "aws_iam_policy" "ci_services" {
  name        = "a2t-mrv-terraform-ci-services"
  description = "Least-privilege policy for the a2t-mrv Terraform CI user."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IAM"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:GetRole", "iam:UpdateRole", "iam:DeleteRole",
          "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
          "iam:ListRolePolicies", "iam:ListRoleTags",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListAttachedRolePolicies",
          "iam:CreateInstanceProfile", "iam:GetInstanceProfile",
          "iam:DeleteInstanceProfile", "iam:ListInstanceProfilesForRole",
          "iam:ListInstanceProfiles",
          "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
          "iam:TagRole", "iam:UntagRole", "iam:TagInstanceProfile", "iam:UntagInstanceProfile",
          "iam:PassRole", "iam:GetPolicy", "iam:GetPolicyVersion",
          "iam:CreateServiceLinkedRole",
        ]
        Resource = "*"
      },
      {
        Sid      = "S3"
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = ["arn:aws:s3:::a2t-mrv-*", "arn:aws:s3:::a2t-mrv-*/*"]
      },
      {
        Sid    = "EC2"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs", "ec2:CreateVpc", "ec2:DeleteVpc",
          "ec2:ModifyVpcAttribute", "ec2:DescribeVpcAttribute",
          "ec2:DescribeSubnets", "ec2:CreateSubnet", "ec2:DeleteSubnet",
          "ec2:ModifySubnetAttribute",
          "ec2:DescribeInternetGateways", "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:DescribeRouteTables", "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
          "ec2:CreateRoute", "ec2:DeleteRoute",
          "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
          "ec2:DescribeSecurityGroups", "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupEgress",
          "ec2:DescribeInstances", "ec2:RunInstances", "ec2:TerminateInstances",
          "ec2:StopInstances", "ec2:StartInstances",
          "ec2:DescribeInstanceAttribute", "ec2:ModifyInstanceAttribute",
          "ec2:DescribeInstanceTypes", "ec2:DescribeInstanceStatus",
          "ec2:DescribeImages", "ec2:DescribeAvailabilityZones",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeAddresses", "ec2:AllocateAddress", "ec2:ReleaseAddress",
          "ec2:AssociateAddress", "ec2:DisassociateAddress",
          "ec2:DescribeVolumes", "ec2:CreateVolume", "ec2:DeleteVolume",
          "ec2:AttachVolume", "ec2:DetachVolume", "ec2:ModifyVolume",
          "ec2:DescribeVolumeAttribute",
          "ec2:DescribeTags", "ec2:CreateTags", "ec2:DeleteTags",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeAccountAttributes",
        ]
        Resource = "*"
      },
      {
        Sid    = "RDS"
        Effect = "Allow"
        Action = [
          "rds:CreateDBInstance", "rds:DescribeDBInstances",
          "rds:ModifyDBInstance", "rds:DeleteDBInstance",
          "rds:CreateDBSubnetGroup", "rds:DescribeDBSubnetGroups",
          "rds:ModifyDBSubnetGroup", "rds:DeleteDBSubnetGroup",
          "rds:CreateDBParameterGroup", "rds:DescribeDBParameterGroups",
          "rds:ModifyDBParameterGroup", "rds:DeleteDBParameterGroup",
          "rds:ResetDBParameterGroup", "rds:DescribeDBParameters",
          "rds:DescribeDBInstanceAutomatedBackups", "rds:DescribeCertificates",
          "rds:AddTagsToResource", "rds:ListTagsForResource", "rds:RemoveTagsFromResource",
          "rds:DescribeDBEngineVersions", "rds:DescribeOrderableDBInstanceOptions",
        ]
        Resource = "*"
      },
      {
        Sid      = "Cognito"
        Effect   = "Allow"
        Action   = "cognito-idp:*"
        Resource = "*"
      },
      {
        Sid      = "SecretsManagerApp"
        Effect   = "Allow"
        Action   = "secretsmanager:*"
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:a2t-mrv/*"
      },
      {
        Sid    = "SecretsManagerRDS"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret", "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue", "secretsmanager:ListSecretVersionIds",
          "secretsmanager:TagResource",
        ]
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:rds!*"
      },
      {
        Sid      = "CodeDeploy"
        Effect   = "Allow"
        Action   = "codedeploy:*"
        Resource = "*"
      },
      {
        Sid    = "KMS"
        Effect = "Allow"
        Action = [
          "kms:DescribeKey", "kms:ListAliases", "kms:ListKeys",
          "kms:CreateGrant", "kms:RetireGrant", "kms:RevokeGrant", "kms:ListGrants",
          "kms:Encrypt", "kms:Decrypt",
          "kms:GenerateDataKey", "kms:GenerateDataKeyWithoutPlaintext",
          "kms:ReEncryptFrom", "kms:ReEncryptTo",
          "kms:GetKeyPolicy", "kms:GetKeyRotationStatus",
        ]
        Resource = "*"
      },
      {
        Sid      = "STS"
        Effect   = "Allow"
        Action   = "sts:GetCallerIdentity"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "ci_services" {
  user       = aws_iam_user.ci.name
  policy_arn = aws_iam_policy.ci_services.arn
}
