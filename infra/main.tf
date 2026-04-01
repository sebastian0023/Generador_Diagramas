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

# ====== VPC ======
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "diagram-generator-vpc"
  }
}

# ====== SUBNET PÚBLICA ======
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "diagram-generator-public-subnet"
  }
}

# ====== AVAILABILITY ZONES ======
data "aws_availability_zones" "available" {
  state = "available"
}

# ====== INTERNET GATEWAY ======
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "diagram-generator-igw"
  }
}

# ====== ROUTE TABLE ======
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.main.id
  }

  tags = {
    Name = "diagram-generator-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ====== SECURITY GROUP PARA EC2 ======
resource "aws_security_group" "backend" {
  name   = "diagram-generator-sg"
  vpc_id = aws_vpc.main.id

  # HTTP para el backend
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Salida
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

  user_data = base64encode(file("${path.module}/user_data.sh"))

  tags = {
    Name = "diagram-generator-backend"
  }

  depends_on = [aws_internet_gateway.main]
}

# ====== S3 BUCKET ======
resource "aws_s3_bucket" "diagrams" {
  bucket = "diagram-generator-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  tags = {
    Name = "diagram-generator-bucket"
  }
}

resource "aws_s3_bucket_public_access_block" "diagrams" {
  bucket = aws_s3_bucket.diagrams.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_cors_configuration" "diagrams" {
  bucket = aws_s3_bucket.diagrams.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# ====== RDS SUBNET GROUP ======
resource "aws_db_subnet_group" "postgres" {
  name       = "diagram-generator-db-subnet"
  subnet_ids = [aws_subnet.public.id]

  tags = {
    Name = "diagram-generator-db-subnet"
  }
}

# ====== SECURITY GROUP PARA RDS ======
resource "aws_security_group" "postgres" {
  name   = "diagram-generator-postgres-sg"
  vpc_id = aws_vpc.main.id

  # PostgreSQL port desde EC2
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
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
  allocated_storage       = 20
  db_name                 = "diagramdb"
  engine                  = "postgres"
  engine_version          = "15.3"
  instance_class          = "db.t3.micro"
  username                = var.db_username
  password                = var.db_password
  parameter_group_name    = "default.postgres15"
  skip_final_snapshot     = true
  publicly_accessible     = true
  db_subnet_group_name    = aws_db_subnet_group.postgres.name
  vpc_security_group_ids  = [aws_security_group.postgres.id]

  tags = {
    Name = "diagram-generator-db"
  }
}
