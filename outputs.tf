output "rds_endpoint" {
  description = "RDS instance connection endpoint (host:port)"
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "RDS instance hostname"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "rds_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.identifier
}

output "rds_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "rds_resource_id" {
  description = "RDS instance resource ID"
  value       = aws_db_instance.main.resource_id
}

output "database_name" {
  description = "Name of the default database"
  value       = aws_db_instance.main.db_name
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.rds_credentials.name
}

output "secret_id" {
  description = "ID of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.rds_credentials.id
}

output "rotation_enabled" {
  description = "Whether automatic rotation is enabled"
  value       = var.enable_rotation
}

output "rotation_schedule" {
  description = "Rotation schedule in days"
  value       = var.rotation_days
}

output "rotation_lambda_arn" {
  description = "ARN of the rotation Lambda function"
  value       = var.enable_rotation ? aws_serverlessapplicationrepository_cloudformation_stack.rotation_lambda[0].outputs["RotationLambdaARN"] : null
}

output "secretsmanager_vpc_endpoint_id" {
  description = "ID of the Secrets Manager VPC endpoint (for rotation Lambda)"
  value       = var.enable_rotation ? aws_vpc_endpoint.secretsmanager[0].id : null
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.main.name
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

# Helpful commands
output "get_secret_command" {
  description = "AWS CLI command to retrieve the secret"
  value       = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.rds_credentials.name} --region ${var.aws_region} --query SecretString --output text | jq"
}

output "rotate_secret_command" {
  description = "AWS CLI command to manually rotate the secret"
  value       = "aws secretsmanager rotate-secret --secret-id ${aws_secretsmanager_secret.rds_credentials.name} --region ${var.aws_region}"
}

output "connection_example" {
  description = "Example of how to connect to the database"
  value = <<-EOT
    # Retrieve credentials
    SECRET=$(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.rds_credentials.name} --region ${var.aws_region} --query SecretString --output text)
    
    # Parse credentials
    DB_HOST=$(echo $SECRET | jq -r .host)
    DB_USER=$(echo $SECRET | jq -r .username)
    DB_PASS=$(echo $SECRET | jq -r .password)
    DB_NAME=$(echo $SECRET | jq -r .dbInstanceIdentifier)
    
    # Connect to database
    mysql -h $DB_HOST -u $DB_USER -p$DB_PASS
  EOT
}

output "python_connection_example" {
  description = "Python code example to connect using the secret"
  value = <<-EOT
    import boto3
    import json
    import pymysql

    # Get secret
    client = boto3.client('secretsmanager', region_name='${var.aws_region}')
    response = client.get_secret_value(SecretId='${aws_secretsmanager_secret.rds_credentials.name}')
    secret = json.loads(response['SecretString'])

    # Connect
    connection = pymysql.connect(
        host=secret['host'],
        user=secret['username'],
        password=secret['password'],
        port=secret['port']
    )
  EOT
}

# =============================================================================
# Web Server Outputs
# =============================================================================

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.web.dns_name
}

output "alb_url" {
  description = "URL to access the RDS Connection Tester"
  value       = "http://${aws_lb.web.dns_name}"
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.web.arn
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "web_security_group_id" {
  description = "ID of the web server security group"
  value       = aws_security_group.web.id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}
