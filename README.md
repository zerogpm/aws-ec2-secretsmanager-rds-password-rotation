# AWS RDS with Secrets Manager + Web Connection Tester

> **⚠️ EDUCATIONAL PROJECT ONLY**
>
> This is a test/learning project with the **bare minimum configuration** to demonstrate AWS RDS + Secrets Manager integration. It is **NOT intended for production use**.
>
> **For production environments, you would need:**
>
> - **Route 53** - Custom domain name
> - **ACM (AWS Certificate Manager)** - SSL/TLS certificates
> - **HTTPS** - Encrypted traffic (currently HTTP only)
> - **WAF (Web Application Firewall)** - Protection against attacks
> - **Enhanced security groups** - More restrictive rules
> - **Private subnets for ALB** - Internal-only access
> - **VPC Flow Logs** - Network monitoring
> - **CloudWatch Alarms** - Monitoring and alerting
> - **Multi-AZ RDS** - High availability
> - **Auto Scaling Group** - EC2 redundancy

This Terraform configuration deploys an AWS RDS MySQL instance with credentials securely stored in AWS Secrets Manager, plus a web-based connection tester accessible via Application Load Balancer.

## Features

- **RDS MySQL** with encryption at rest
- **AWS Secrets Manager** for credential storage
- **Automatic Secret Rotation** - Lambda-based credential rotation using AWS SAR template
- **Web Connection Tester** - Browser-based UI to test RDS connectivity
- **ALB + Private EC2** - Secure architecture with no public EC2 IPs
- **VPC with Public/Private Subnets** for network isolation
- **NAT Gateway** for EC2 outbound access
- **VPC Endpoints** for secure Secrets Manager access (when rotation enabled)
- **Security Groups** with least-privilege access
- **Automated Backups** with configurable retention
- **CloudWatch Logs** for RDS monitoring (error, general, slowquery logs) with 1-day retention

## Architecture

```
                    Internet
                        │
                        ▼
            ┌───────────────────────┐
            │  Application Load     │
            │  Balancer (public)    │
            └───────────┬───────────┘
                        │ HTTP :80
┌───────────────────────┼───────────────────────────────────┐
│                  VPC  │                                   │
│  ┌────────────────────┴───────────────────────────────┐  │
│  │              Public Subnets (10.0.10.0/24)         │  │
│  │                                                     │  │
│  │     ┌─────────────┐                                │  │
│  │     │ NAT Gateway │                                │  │
│  │     └──────┬──────┘                                │  │
│  └────────────┼───────────────────────────────────────┘  │
│               │                                           │
│  ┌────────────┼───────────────────────────────────────┐  │
│  │   Private  │ Subnets (10.0.1.0/24, 10.0.2.0/24)    │  │
│  │            ▼                                        │  │
│  │     ┌─────────────┐         ┌─────────────────┐    │  │
│  │     │     EC2     │────────►│   RDS MySQL     │    │  │
│  │     │  (Node.js)  │         │  (Private)      │    │  │
│  │     └──────┬──────┘         └────────▲────────┘    │  │
│  │            │                         │              │  │
│  │            │    ┌────────────────────┘              │  │
│  │            │    │                                   │  │
│  │     ┌──────┴────┴────┐     ┌───────────────────┐   │  │
│  │     │ VPC Endpoint   │     │  Rotation Lambda  │   │  │
│  │     │ (Secrets Mgr)  │◄────│  (AWS SAR)        │   │  │
│  │     └───────┬────────┘     └───────────────────┘   │  │
│  │             │                                       │  │
│  └─────────────┼───────────────────────────────────────┘ │
│                │                                          │
└────────────────┼──────────────────────────────────────────┘
                 │
                 ▼
    ┌─────────────────────────┐
    │  AWS Secrets Manager    │
    │  (RDS Credentials)      │
    │  + Auto Rotation        │
    └─────────────────────────┘
```

---

## Prerequisites Installation

### Step 1: Install Terraform

**Windows (using Chocolatey):**

```powershell
choco install terraform
```

**Windows (manual):**

1. Download from https://developer.hashicorp.com/terraform/downloads
2. Extract the zip file
3. Add the folder to your system PATH

**macOS:**

```bash
brew install terraform
```

**Linux (Ubuntu/Debian):**

```bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**Verify installation:**

```bash
terraform --version
```

---

### Step 2: Install AWS CLI

**Windows (using MSI installer):**

1. Download from https://aws.amazon.com/cli/
2. Run the installer
3. Restart your terminal

**Windows (using Chocolatey):**

```powershell
choco install awscli
```

**macOS:**

```bash
brew install awscli
```

**Linux:**

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Verify installation:**

```bash
aws --version
```

---

### Step 3: Configure AWS Credentials

**Option A: Using AWS Configure (Recommended)**

```bash
aws configure
```

You will be prompted:

```
AWS Access Key ID [None]: YOUR_ACCESS_KEY_ID
AWS Secret Access Key [None]: YOUR_SECRET_ACCESS_KEY
Default region name [None]: us-east-1
Default output format [None]: json
```

**Option B: Manual Configuration**

Create the credentials file:

**Windows:** `C:\Users\YOUR_USERNAME\.aws\credentials`
**macOS/Linux:** `~/.aws/credentials`

```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
```

Create the config file:

**Windows:** `C:\Users\YOUR_USERNAME\.aws\config`
**macOS/Linux:** `~/.aws/config`

```ini
[default]
region = us-east-1
output = json
```

**Verify configuration:**

```bash
aws sts get-caller-identity
```

Expected output:

```json
{
  "UserId": "AIDAXXXXXXXXXXXXXXXXX",
  "Account": "123456789012",
  "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

---

### Step 4: Required IAM Permissions

Your AWS user/role needs these managed policies:

- `AmazonEC2FullAccess`
- `AmazonRDSFullAccess`
- `SecretsManagerReadWrite`
- `ElasticLoadBalancingFullAccess`
- `AmazonVPCFullAccess`
- `CloudWatchLogsFullAccess`
- `AWSCloudFormationFullAccess` (needed for rotation Lambda)
- `AWSLambda_FullAccess` (needed for rotation Lambda)

Plus a **custom policy for IAM** (do NOT use `IAMFullAccess`):
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:TagRole",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
      "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
      "iam:PassRole", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole"
    ],
    "Resource": "*"
  }]
}
```

> **Why not IAMFullAccess?** It allows creating admin users and escalating privileges - a major security risk. The custom policy above only allows managing roles needed for EC2 and Lambda.

---

## Deployment Steps

### Step 1: Clone/Download the Project

```bash
cd ~/Downloads/files   # or wherever your files are located
```

### Step 2: Initialize Terraform

```bash
terraform init
```

This downloads the required AWS provider plugins.

### Step 3: Preview Changes

```bash
terraform plan
```

Review the resources that will be created (~30 resources).

### Step 4: Deploy

```bash
terraform apply
```

Type `yes` when prompted.

**Deployment takes approximately 10-15 minutes** (RDS creation is the slowest part).

### Step 5: Access the Web Tester

After deployment completes, you'll see outputs including:

```
alb_url = "http://web-xxxxxxxxx.us-east-1.elb.amazonaws.com"
```

1. Wait 2-3 minutes for EC2 to finish bootstrapping
2. Open the `alb_url` in your browser
3. Click **"Test Connection"**
4. You should see a success message with MySQL version

---

## Configuration

### Customize Variables

Edit `variables.tf` or create a `terraform.tfvars` file:

```hcl
# terraform.tfvars

aws_region   = "us-east-1"
project_name = "myapp"
environment  = "dev"

# Database
db_instance_class = "db.t3.micro"
db_name           = "myappdb"
db_username       = "admin"

# EC2
ec2_instance_type = "t3.micro"
```

### Key Variables

| Variable             | Description                        | Default       |
| -------------------- | ---------------------------------- | ------------- |
| `aws_region`         | AWS region                         | `us-east-1`   |
| `project_name`       | Resource naming prefix             | `myapp`       |
| `db_instance_class`  | RDS instance size                  | `db.t3.micro` |
| `db_engine_version`  | MySQL version                      | `8.0`         |
| `ec2_instance_type`  | EC2 instance size                  | `t3.micro`    |
| `enable_rotation`    | Enable automatic secret rotation   | `true`        |
| `rotation_days`      | Days between rotations (1-365)     | `365`         |
| `rotate_immediately` | Rotate secret immediately on create| `false`       |

---

## Using the Deployed Resources

### Access the Web Connection Tester

```bash
# Get the URL
terraform output alb_url
```

Open in browser and click "Test Connection".

### Retrieve Database Credentials

```bash
# Get the AWS CLI command
terraform output get_secret_command

# Or run directly
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw secret_name) \
  --query SecretString --output text | jq
```

### Connect via MySQL Client

```bash
# Get credentials
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw secret_name) \
  --query SecretString --output text)

DB_HOST=$(echo $SECRET | jq -r .host)
DB_USER=$(echo $SECRET | jq -r .username)
DB_PASS=$(echo $SECRET | jq -r .password)

# Connect (requires mysql client and VPC access)
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS myappdb
```

### Python Connection Example

```python
import boto3
import json
import pymysql

# Get credentials from Secrets Manager
client = boto3.client('secretsmanager', region_name='us-east-1')
response = client.get_secret_value(SecretId='myapp-rds-credentials-xxxxx')
secret = json.loads(response['SecretString'])

# Connect to database
connection = pymysql.connect(
    host=secret['host'],
    user=secret['username'],
    password=secret['password'],
    database='myappdb',
    port=secret['port']
)
```

### Node.js Connection Example

```javascript
const {
  SecretsManagerClient,
  GetSecretValueCommand,
} = require("@aws-sdk/client-secrets-manager");
const mysql = require("mysql2/promise");

async function getConnection() {
  const client = new SecretsManagerClient({ region: "us-east-1" });
  const response = await client.send(
    new GetSecretValueCommand({
      SecretId: "myapp-rds-credentials-xxxxx",
    }),
  );

  const secret = JSON.parse(response.SecretString);

  return mysql.createConnection({
    host: secret.host,
    user: secret.username,
    password: secret.password,
    database: "myappdb",
    port: secret.port,
  });
}
```

---

## Cleanup / Destroy

To remove all AWS resources:

```bash
terraform destroy
```

Type `yes` when prompted.

**Verify cleanup:**

```bash
terraform state list
# Should return empty (no output)
```

---

## Troubleshooting

### Web Page Not Loading

1. **Wait for EC2 bootstrap** - Takes 2-3 minutes after deployment
2. **Check target group health:**
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn $(terraform output -raw target_group_arn 2>/dev/null || echo "check AWS console")
   ```

### Connection Test Fails

| Error                 | Cause                       | Solution                              |
| --------------------- | --------------------------- | ------------------------------------- |
| `SECRET_NOT_FOUND`    | Secret doesn't exist        | Verify secret name in Secrets Manager |
| `ACCESS_DENIED`       | EC2 missing IAM permissions | Check IAM role policy                 |
| `TIMEOUT`             | Network issue               | Verify security groups allow traffic  |
| `INVALID_CREDENTIALS` | Wrong password              | Secret may be out of sync             |

### Terraform Destroy Fails

If destroy fails due to dependencies:

```bash
# Retry destroy
terraform destroy

# If still failing, check AWS Console for stuck resources
```

### Check EC2 Logs

```bash
# Via AWS Console: EC2 > Instance > Actions > Monitor > Get System Log
# Or via Systems Manager if enabled
```

---

## Cost Estimation

Approximate monthly costs (us-east-1) with auto-rotation enabled (default):

| Resource        | Configuration   | Est. Cost    |
| --------------- | --------------- | ------------ |
| RDS db.t3.micro | Single-AZ, 20GB | ~$15/month   |
| EC2 t3.micro    | On-demand       | ~$8/month    |
| ALB             | Basic usage     | ~$20/month   |
| NAT Gateway     | Basic usage     | ~$35/month   |
| VPC Endpoint    | Secrets Manager | ~$15/month   |
| Secrets Manager | 1 secret        | ~$0.40/month |

**Total estimated cost: ~$95/month** (with rotation enabled)

**Cost saving options:**
- Disable rotation (`enable_rotation = false`): Saves ~$15/month, total ~$80/month
- NAT Gateway is the most expensive component - consider VPC endpoints for other services too

---

## Automatic Secret Rotation

> **Enabled by Default:** This project has automatic secret rotation **enabled by default** (`enable_rotation = true`) because it's a security best practice. Credentials should be rotated regularly to minimize the impact of compromised secrets.

This project includes full support for **automatic secret rotation** using AWS Secrets Manager and a Lambda function from the AWS Serverless Application Repository (SAR).

### Why Auto-Rotation is Enabled by Default

| Reason | Explanation |
|--------|-------------|
| **Security best practice** | Regularly rotating credentials limits the window of exposure if a secret is compromised |
| **Compliance requirements** | Many security standards (PCI-DSS, SOC2, HIPAA) require credential rotation |
| **Educational purpose** | This project teaches AWS secrets management - rotation is a key part of that |
| **Zero downtime** | AWS handles rotation seamlessly without breaking your application |

### Disable Auto-Rotation (Not Recommended)

If you need to disable rotation (e.g., for cost savings in development), set:

```hcl
# terraform.tfvars
enable_rotation = false
```

Or via command line:
```bash
terraform apply -var="enable_rotation=false"
```

**What happens when disabled:**
- No Lambda function is created
- No VPC endpoint is created
- No additional security groups for rotation
- No IAM roles for rotation Lambda
- **Saves ~$15/month** in VPC endpoint costs

**You can still rotate manually** using AWS CLI (see [Manual Rotation When Auto-Rotation is Disabled](#manual-rotation-when-auto-rotation-is-disabled) section below).

### How It Works

When `enable_rotation = true`, Terraform deploys:

1. **Rotation Lambda** - AWS-managed MySQL rotation function from SAR (`SecretsManagerRDSMySQLRotationSingleUser`)
2. **VPC Endpoint** - Private endpoint for Secrets Manager (so Lambda doesn't need internet access)
3. **Security Groups** - Allow Lambda to connect to RDS on port 3306
4. **IAM Permissions** - Lambda role with least-privilege access to rotate credentials

The rotation process (handled automatically by AWS):
1. **Create** - Generate a new random password
2. **Set** - Update the RDS database with the new password
3. **Test** - Verify the new credentials work
4. **Finish** - Mark the new secret version as current

### Why Use AWS SAR for the Lambda Function?

> **For newcomers:** You might wonder why we don't write our own Lambda function code.

The rotation Lambda comes from **AWS Serverless Application Repository (SAR)** - a library of pre-built, AWS-maintained applications. We use it because:

| Reason | Explanation |
|--------|-------------|
| **No code to write** | AWS provides the complete rotation logic - you don't need to write Python/Node.js code |
| **AWS maintains it** | Security patches and bug fixes are handled by AWS automatically |
| **Battle-tested** | Used by thousands of AWS customers, thoroughly tested |
| **Best practices** | Implements AWS's recommended 4-step rotation pattern |
| **Database support** | AWS provides templates for MySQL, PostgreSQL, MariaDB, SQL Server, etc. |

The Lambda code handles complex tasks like:
- Connecting to RDS and changing passwords
- Managing secret versions (AWSPENDING → AWSCURRENT)
- Rollback if rotation fails
- Proper error handling

**Alternative:** If you need custom rotation logic (e.g., rotating API keys, custom databases), you would write your own Lambda function. See [AWS documentation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html).

### Why Do We Need a VPC Endpoint?

> **For newcomers:** This is a common point of confusion in AWS networking.

**The Problem:**
- Our rotation Lambda runs inside a **private subnet** (no internet access)
- The Lambda needs to call AWS Secrets Manager API to update the secret
- AWS Secrets Manager is a **public AWS service** (normally accessed via internet)
- Private subnet → No internet → Cannot reach Secrets Manager! ❌

**The Solution: VPC Endpoint**

A VPC Endpoint creates a **private connection** between your VPC and AWS services:

```
WITHOUT VPC Endpoint:
┌─────────────────┐     ❌ No route      ┌─────────────────┐
│ Lambda in       │ ─────────────────── │ Secrets Manager │
│ Private Subnet  │   (needs internet)  │ (Public Service)│
└─────────────────┘                      └─────────────────┘

WITH VPC Endpoint:
┌─────────────────┐     ✅ Private       ┌─────────────────┐
│ Lambda in       │ ══════════════════► │ Secrets Manager │
│ Private Subnet  │   (VPC Endpoint)    │ (via endpoint)  │
└─────────────────┘                      └─────────────────┘
```

| Benefit | Explanation |
|---------|-------------|
| **No internet required** | Lambda can reach Secrets Manager without NAT Gateway |
| **More secure** | Traffic stays within AWS network, never touches internet |
| **Lower latency** | Direct path to AWS service |
| **Cost effective** | Cheaper than routing through NAT Gateway for this traffic |

**Types of VPC Endpoints:**
- **Interface Endpoint** (what we use) - Creates an ENI in your subnet with a private IP
- **Gateway Endpoint** - For S3 and DynamoDB only, free of charge

### Enable Auto-Rotation

**Option 1: Using terraform.tfvars**

```hcl
# terraform.tfvars
enable_rotation    = true
rotation_days      = 30    # Rotate every 30 days
rotate_immediately = false # Set to true to rotate right after deployment
```

**Option 2: Command line**

```bash
terraform apply -var="enable_rotation=true" -var="rotation_days=30"
```

### Rotation Configuration Options

| Variable             | Description                                     | Default |
| -------------------- | ----------------------------------------------- | ------- |
| `enable_rotation`    | Enable automatic rotation                       | `true`  |
| `rotation_days`      | Days between automatic rotations (1-365)        | `365`   |
| `rotation_schedule`  | Cron expression (overrides `rotation_days`)     | `null`  |
| `rotate_immediately` | Rotate the secret immediately after creation    | `false` |

### Example Rotation Schedules

```hcl
# Rotate every 30 days
rotation_days = 30

# Or use cron expressions for more control:
# Every Sunday at 2 AM UTC
rotation_schedule = "cron(0 2 ? * SUN *)"

# First day of every month at midnight
rotation_schedule = "cron(0 0 1 * ? *)"
```

### Verify Auto-Rotation is Configured

After deployment, verify that automatic rotation is properly configured:

```bash
# Check rotation configuration
aws secretsmanager describe-secret \
  --secret-id $(terraform output -raw secret_name) \
  --query '{
    RotationEnabled: RotationEnabled,
    RotationLambdaARN: RotationLambdaARN,
    RotationRules: RotationRules,
    NextRotationDate: NextRotationDate
  }'
```

Expected output:
```json
{
  "RotationEnabled": true,
  "RotationLambdaARN": "arn:aws:lambda:us-east-1:...:function:myapp-mysql-rotation-lambda",
  "RotationRules": {
    "AutomaticallyAfterDays": 30
  },
  "NextRotationDate": "2024-02-15T..."
}
```

### Test Rotation

You don't need to wait for the scheduled rotation. Test it immediately:

**Option 1: Deploy with `rotate_immediately = true`**
```hcl
enable_rotation    = true
rotation_days      = 30
rotate_immediately = true  # Rotates right after deployment
```

**Option 2: Trigger manual rotation anytime**
```bash
# Trigger rotation now
aws secretsmanager rotate-secret \
  --secret-id $(terraform output -raw secret_name)

# Check rotation status
aws secretsmanager describe-secret \
  --secret-id $(terraform output -raw secret_name) \
  --query '{LastRotated: LastRotatedDate, NextRotation: NextRotationDate}'
```

**Option 3: Use short schedule for testing**
```hcl
# Rotate every hour (for testing only!)
rotation_schedule = "rate(1 hour)"
```

Both manual and automatic rotation use the **same Lambda function** - triggering manually is a valid way to test the rotation logic.

### Monitor Rotation

```bash
# View rotation Lambda logs
aws logs tail /aws/lambda/myapp-mysql-rotation-lambda --follow

# Or find the log group first
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/"

# Check secret versions (shows AWSCURRENT and AWSPREVIOUS after rotation)
aws secretsmanager list-secret-version-ids \
  --secret-id $(terraform output -raw secret_name)

# Verify your application still connects
terraform output alb_url
# Open the URL and click "Test Connection"
```

### Resources Created (when rotation enabled)

| Resource                                      | Purpose                                    |
| --------------------------------------------- | ------------------------------------------ |
| `aws_serverlessapplicationrepository_...`     | MySQL rotation Lambda from AWS SAR         |
| `aws_vpc_endpoint.secretsmanager`             | Private access to Secrets Manager          |
| `aws_security_group.rotation_lambda`          | Security group for rotation Lambda         |
| `aws_security_group.vpc_endpoint`             | Security group for VPC endpoint            |
| `aws_security_group_rule.rds_from_...`        | Allow Lambda to access RDS                 |
| `aws_secretsmanager_secret_rotation.rds_...`  | Rotation configuration                     |

### Cost Impact

When rotation is enabled, additional costs include:
- **VPC Endpoint**: ~$7.50/month per AZ (2 AZs = ~$15/month)
- **Lambda invocations**: Minimal (only runs during rotation)

### Manual Rotation When Auto-Rotation is Disabled

If you've disabled auto-rotation (`enable_rotation = false`) but still need to rotate credentials occasionally, you can do it manually using AWS CLI. **No Lambda or VPC endpoint is needed** for manual rotation.

**Step 1: Generate a new password**
```bash
NEW_PASSWORD=$(aws secretsmanager get-random-password \
  --password-length 32 \
  --exclude-punctuation \
  --query RandomPassword --output text)
echo "New password generated (don't share this!)"
```

**Step 2: Update RDS with the new password**
```bash
aws rds modify-db-instance \
  --db-instance-identifier $(terraform output -raw rds_instance_id) \
  --master-user-password "$NEW_PASSWORD" \
  --apply-immediately
```

**Step 3: Update the secret in Secrets Manager**
```bash
# Get current secret
SECRET_ID=$(terraform output -raw secret_name)
CURRENT_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id $SECRET_ID \
  --query SecretString --output text)

# Update password in the JSON
UPDATED_SECRET=$(echo $CURRENT_SECRET | jq --arg pwd "$NEW_PASSWORD" '.password = $pwd')

# Save updated secret
aws secretsmanager put-secret-value \
  --secret-id $SECRET_ID \
  --secret-string "$UPDATED_SECRET"
```

**Step 4: Wait and verify**
```bash
# Wait for RDS to apply the change (1-2 minutes)
echo "Waiting for RDS to apply password change..."
sleep 60

# Test the connection via web tester
terraform output alb_url
```

> **Note:** Manual rotation requires you to update BOTH RDS and Secrets Manager. If you only update one, your application will fail to connect!

---

## Security Notes

- EC2 has no public IP (accessed only via ALB)
- RDS is in private subnets (not publicly accessible)
- Security groups follow least-privilege principle
- Secrets Manager encrypts credentials at rest
- IAM role grants EC2 only necessary permissions
- **CloudWatch logs retained for 1 day** - This is an educational project, so logs are kept short-term to minimize storage costs. In production, increase retention (e.g., 30-90 days) for compliance and debugging

---

## Files Overview

| File           | Description                                    |
| -------------- | ---------------------------------------------- |
| `main.tf`      | Main infrastructure (VPC, RDS, EC2, ALB, etc.) |
| `variables.tf` | Input variables with defaults                  |
| `outputs.tf`   | Output values (URLs, ARNs, etc.)               |
| `user_data.sh` | EC2 bootstrap script (Node.js app)             |

---

## License

MIT
