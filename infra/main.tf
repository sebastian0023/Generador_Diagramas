terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ====== VPC ======
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "diagram-generator-vpc"
  }
}

# ====== PUBLIC SUBNET (AZ 0) ======
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "diagram-generator-public-subnet"
  }
}

# ====== PRIVATE SUBNET A (AZ 0) - for RDS ======
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "diagram-generator-private-subnet-a"
  }
}

# ====== PRIVATE SUBNET B (AZ 1) - for RDS (AWS requires 2 AZs) ======
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "diagram-generator-private-subnet-b"
  }
}

# ====== INTERNET GATEWAY ======
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "diagram-generator-igw"
  }
}

# ====== ROUTE TABLE (public) ======
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "diagram-generator-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ====== ECR REPOSITORY ======
resource "aws_ecr_repository" "backend" {
  name                 = "diagram-generator/backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "diagram-generator-ecr"
  }
}

# ====== IAM ROLE FOR EC2 ======
resource "aws_iam_role" "ec2" {
  name = "diagram-generator-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Allow EC2 to pull images from ECR
resource "aws_iam_role_policy" "ec2_ecr" {
  name = "ecr-pull"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.diagrams.arn,
          "${aws_s3_bucket.diagrams.arn}/*"
        ]
      }
    ]
  })
}

# SSM Session Manager — allows SSH-less access
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "diagram-generator-ec2-profile"
  role = aws_iam_role.ec2.name
}

# ====== SECURITY GROUP FOR EC2 ======
resource "aws_security_group" "backend" {
  name   = "diagram-generator-sg"
  vpc_id = aws_vpc.main.id

  # Backend API - restrict to known CIDR or ALB in future
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Backend API (lock down to ALB SG before production)"
  }

  # SSH - restricted to your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "SSH access from operator IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "diagram-generator-sg"
  }
}

# ====== EC2 INSTANCE ======
resource "aws_instance" "backend" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  key_name               = var.ec2_key_pair_name

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    ecr_registry   = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
    ecr_repo       = "diagram-generator/backend"
    aws_region     = var.aws_region
    db_password    = var.db_password
    db_username    = var.db_username
    s3_bucket      = "diagram-generator-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
    allowed_origin = var.cors_allowed_origin
  }))

  tags = {
    Name = "diagram-generator-backend"
  }

  depends_on = [aws_internet_gateway.main, aws_iam_instance_profile.ec2]
}

# ====== S3 BUCKET ======
resource "aws_s3_bucket" "diagrams" {
  bucket = "diagram-generator-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  tags = {
    Name = "diagram-generator-bucket"
  }
}

# Block all public access - backend accesses via IAM role, not public URLs
resource "aws_s3_bucket_public_access_block" "diagrams" {
  bucket = aws_s3_bucket.diagrams.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "diagrams" {
  bucket = aws_s3_bucket.diagrams.id

  cors_rule {
    allowed_headers = ["Authorization", "Content-Type"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = [var.cors_allowed_origin == "" ? "http://localhost:4200" : var.cors_allowed_origin]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# ====== RDS SUBNET GROUP (private subnets, 2 AZs required) ======
resource "aws_db_subnet_group" "postgres" {
  name       = "diagram-generator-db-subnet"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name = "diagram-generator-db-subnet"
  }
}

# ====== SECURITY GROUP FOR RDS ======
resource "aws_security_group" "postgres" {
  name   = "diagram-generator-postgres-sg"
  vpc_id = aws_vpc.main.id

  # PostgreSQL - only from EC2 security group
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
    description     = "PostgreSQL from EC2 only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "diagram-generator-postgres-sg"
  }
}

# ====== RDS POSTGRESQL ======
resource "aws_db_instance" "postgres" {
  allocated_storage      = 20
  db_name                = "diagramdb"
  engine                 = "postgres"
  engine_version         = "15.3"
  instance_class         = "db.t3.micro"
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = "default.postgres15"
  skip_final_snapshot    = true
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]

  backup_retention_period = 7

  tags = {
    Name = "diagram-generator-db"
  }
}
