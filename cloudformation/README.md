# cloudformation/

CloudFormation stacks for resources not managed by Terraform.

| Stack | File | Purpose |
|---|---|---|
| `a2t-mrv-codedeploy` | `codedeploy.yml` | CodeDeploy application, deployment group, and IAM service role |

## Deploying

Deploy the CodeDeploy stack once (idempotent on subsequent runs):

```sh
aws cloudformation deploy \
  --stack-name a2t-mrv-codedeploy \
  --template-file cloudformation/codedeploy.yml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides RevisionsBucketName=<your-storage-bucket-name>
```

`aws cloudformation describe-stacks --stack-name a2t-mrv-codedeploy` should show `CREATE_COMPLETE` or `UPDATE_COMPLETE`.

## Prerequisites

- The EC2 instance must be tagged `CodeDeployApp=livedata` (set by Terraform in `terraform/modules/infra`).
- The CodeDeploy agent must be installed and running on the instance (provisioned by `user_data.sh.tftpl` in the same module).
- The `RevisionsBucketName` S3 bucket must grant `s3:GetObject` to the EC2 IAM role (`a2t-mrv-ec2`). The existing CRCF storage bucket already satisfies this.
