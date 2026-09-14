# terraform/bootstrap

One-time setup applied **by a human with admin credentials** before CI is wired up.
It creates the CI IAM user and attaches its least-privilege policy.

## When to run this

- First-time account setup (new environment, scratch deploy)
- When the CI policy needs an update (add it here, then re-apply)

## How to apply

```sh
# From this directory, with admin AWS credentials active:
cd terraform/bootstrap
terraform init
terraform apply -var="account_id=<YOUR_AWS_ACCOUNT_ID>"
```

After apply, create an access key for the CI user in the AWS Console
(IAM → Users → a2t-mrv-terraform-ci → Security credentials → Create access key)
and add the values to GitHub Actions secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## What this does NOT manage

- The Terraform state bucket (`a2t-mrv-tfstate-<account_id>`) — bootstrapped
  automatically by the `bootstrap state bucket` step in `.github/workflows/terraform.yml`.
- SSH key pair (`a2t-mrv-prod`) — create in EC2 → Key Pairs before the first
  `terraform apply` of the main root, or the EC2 instance will fail to launch.
