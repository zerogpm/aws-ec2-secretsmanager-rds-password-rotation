variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "myapp"

  validation {
    condition     = length(var.project_name) <= 20
    error_message = "Project name must be 20 characters or less."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# Database Configuration
variable "db_name" {
  description = "Name of the default database to create"
  type        = string
  default     = "myappdb"
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "admin"
}

variable "db_engine_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum storage for autoscaling in GB (0 to disable)"
  type        = number
  default     = 100
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
  default     = false
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated backups (0 to disable)"
  type        = number
  default     = 7

  validation {
    condition     = var.db_backup_retention_period >= 0 && var.db_backup_retention_period <= 35
    error_message = "Backup retention period must be between 0 and 35 days."
  }
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying the RDS instance"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection for the RDS instance"
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "ARN of KMS key for encryption (uses AWS managed key if not specified)"
  type        = string
  default     = null
}

# Secrets Manager Configuration
variable "secret_recovery_window" {
  description = "Number of days to allow recovery of deleted secrets (0 for immediate deletion)"
  type        = number
  default     = 7

  validation {
    condition     = var.secret_recovery_window == 0 || (var.secret_recovery_window >= 7 && var.secret_recovery_window <= 30)
    error_message = "Recovery window must be 0 or between 7 and 30 days."
  }
}

# Rotation Configuration
variable "enable_rotation" {
  description = "Enable automatic secret rotation (recommended for production security)"
  type        = bool
  default     = true
}

variable "rotation_days" {
  description = "Number of days between automatic rotations"
  type        = number
  default     = 365

  validation {
    condition     = var.rotation_days >= 1 && var.rotation_days <= 365
    error_message = "Rotation days must be between 1 and 365."
  }
}

variable "rotation_schedule" {
  description = "Cron expression for rotation schedule (optional, overrides rotation_days)"
  type        = string
  default     = null
}

variable "rotate_immediately" {
  description = "Rotate the secret immediately upon creation"
  type        = bool
  default     = false
}

# EC2 Configuration
variable "ec2_instance_type" {
  description = "EC2 instance type for the web server"
  type        = string
  default     = "t3.micro"
}
