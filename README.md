# AWS RDS with Secrets Manager + Web Connection Tester

> **⚠️ EDUCATIONAL PROJECT ONLY**
>
> This is a test/learning project with the **bare minimum configuration** to demonstrate AWS RDS + Secrets Manager integration. It is **NOT intended for production use**.
>
> **For production environments, you would need:**
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
> - **Secrets rotation with Lambda** - Automatic credential rotation

This Terraform configuration deploys an AWS RDS MySQL instance with credentials securely stored in AWS Secrets Manager, plus a web-based connection tester accessible via Application Load Balancer.

## Features

- **RDS MySQL** with encryption at rest
- **AWS Secrets Manager** for credential storage
- **Web Connection Tester** - Browser-based UI to test RDS connectivity
- **ALB + Private EC2** - Secure architecture with no public EC2 IPs
- **VPC with Public/Private Subnets** for network isolation
- **NAT Gateway** for EC2 outbound access
- **Security Groups** with least-privilege access
- **Automated Backups** with configurable retention
- **CloudWatch Logs** for monitoring

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
│  │     └──────┬──────┘         └─────────────────┘    │  │
│  │            │                                        │  │
│  └────────────┼────────────────────────────────────────┘ │
│               │                                           │
└───────────────┼───────────────────────────────────────────┘
                │
                ▼
    ┌─────────────────────────┐
    │  AWS Secrets Manager    │
    │  (RDS Credentials)      │
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

Your AWS user/role needs these permissions:
- `AmazonEC2FullAccess`
- `AmazonRDSFullAccess`
- `SecretsManagerReadWrite`
- `IAMFullAccess`
- `ElasticLoadBalancingFullAccess`
- `AmazonVPCFullAccess`

Or use `AdministratorAccess` for simplicity (not recommended for production).

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

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | `us-east-1` |
| `project_name` | Resource naming prefix | `myapp` |
| `db_instance_class` | RDS instance size | `db.t3.micro` |
| `db_engine_version` | MySQL version | `8.0` |
| `ec2_instance_type` | EC2 instance size | `t3.micro` |
| `enable_rotation` | Auto-rotate secrets | `false` |

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
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const mysql = require('mysql2/promise');

async function getConnection() {
  const client = new SecretsManagerClient({ region: 'us-east-1' });
  const response = await client.send(new GetSecretValueCommand({
    SecretId: 'myapp-rds-credentials-xxxxx'
  }));

  const secret = JSON.parse(response.SecretString);

  return mysql.createConnection({
    host: secret.host,
    user: secret.username,
    password: secret.password,
    database: 'myappdb',
    port: secret.port
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

| Error | Cause | Solution |
|-------|-------|----------|
| `SECRET_NOT_FOUND` | Secret doesn't exist | Verify secret name in Secrets Manager |
| `ACCESS_DENIED` | EC2 missing IAM permissions | Check IAM role policy |
| `TIMEOUT` | Network issue | Verify security groups allow traffic |
| `INVALID_CREDENTIALS` | Wrong password | Secret may be out of sync |

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

Approximate monthly costs (us-east-1):

| Resource | Configuration | Est. Cost |
|----------|---------------|-----------|
| RDS db.t3.micro | Single-AZ, 20GB | ~$15/month |
| EC2 t3.micro | On-demand | ~$8/month |
| ALB | Basic usage | ~$20/month |
| NAT Gateway | Basic usage | ~$35/month |
| Secrets Manager | 1 secret | ~$0.40/month |

**Total estimated cost: ~$80/month**

**Note:** NAT Gateway is the most expensive component. For cost savings in dev/test, consider using VPC endpoints instead.

---

## Security Notes

- EC2 has no public IP (accessed only via ALB)
- RDS is in private subnets (not publicly accessible)
- Security groups follow least-privilege principle
- Secrets Manager encrypts credentials at rest
- IAM role grants EC2 only necessary permissions

---

## Files Overview

| File | Description |
|------|-------------|
| `main.tf` | Main infrastructure (VPC, RDS, EC2, ALB, etc.) |
| `variables.tf` | Input variables with defaults |
| `outputs.tf` | Output values (URLs, ARNs, etc.) |
| `user_data.sh` | EC2 bootstrap script (Node.js app) |

---

## License

MIT
