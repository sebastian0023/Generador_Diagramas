# 🚀 INSTRUCCIONES COMPLETAS - Diagram Generator MVP

**Objetivo:** Ejecutar todo lo más rápido posible. NO hay fechas, puro desarrollo.

---

## ⚡ Paso 0: Requisitos previos (10 min)

### Instalar herramientas

```bash
# 1. Verificar Node.js instalado
node --version
npm --version
# Si no: https://nodejs.org/en/download/

# 2. Instalar Terraform
brew install terraform  # macOS
# O Windows/Linux: https://www.terraform.io/downloads
terraform --version

# 3. Instalar AWS CLI
brew install awscli
aws --version

# 4. Instalar Angular CLI
npm install -g @angular/cli
ng version

# 5. Crear cuenta AWS si no tienes
# Ir a: https://aws.amazon.com/

# 6. Generar AWS Access Keys
# AWS Console → IAM → Users → Security Credentials → Access Keys
# Guardar: Access Key ID y Secret Access Key
```

### Configurar AWS

```bash
# Configurar credenciales
aws configure

# Cuando pregunte:
# AWS Access Key ID: [PEGA_TU_ACCESS_KEY]
# AWS Secret Access Key: [PEGA_TU_SECRET_KEY]
# Default region: us-east-1
# Default output format: json

# Verificar que funciona
aws sts get-caller-identity
# Debe mostrar tu información de AWS
```

---

## 🏗️ Paso 1: Crear infraestructura con Terraform (30 min)

### 1.1 Crear carpeta del proyecto

```bash
# En tu máquina local
mkdir diagram-generator
cd diagram-generator

# Crear subcarpetas
mkdir infra backend frontend
mkdir -p .github/workflows

# Inicializar git
git init
echo "node_modules/
.env
.env.local
.DS_Store
dist/
*.log
infra/terraform.tfstate*
infra/.terraform/
" > .gitignore
```

### 1.2 Crear archivos Terraform

**Crear: `infra/main.tf`**

```hcl
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
```

**Crear: `infra/variables.tf`**

```hcl
variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block for SSH access (your IP/32)"
  default     = "0.0.0.0/0"  # CAMBIAR A TU IP DESPUÉS
  type        = string
}

variable "db_username" {
  description = "RDS master username"
  default     = "diagramadmin"
  type        = string
}

variable "db_password" {
  description = "RDS master password"
  sensitive   = true
  type        = string
}
```

**Crear: `infra/outputs.tf`**

```hcl
output "backend_public_ip" {
  description = "Public IP of EC2 backend"
  value       = aws_instance.backend.public_ip
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.diagrams.bucket
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.postgres.db_name
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}
```

**Crear: `infra/terraform.tfvars`** (GITIGNORE este archivo)

```hcl
aws_region       = "us-east-1"
allowed_ssh_cidr = "0.0.0.0/32"           # CAMBIAR A TU IP: "203.0.113.45/32"
db_username      = "diagramadmin"
db_password      = "REPLACE_WITH_STRONG_PASSWORD"
```

**Crear: `infra/user_data.sh`** (script para iniciar EC2)

```bash
#!/bin/bash
set -e

echo "Starting Diagram Generator backend setup..."

# Update system
sudo yum update -y

# Install Node.js
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs

# Install git
sudo yum install -y git

# Install PM2
sudo npm install -g pm2

# Create app directory
mkdir -p /opt/diagram-generator
cd /opt/diagram-generator

# Clone repository (CAMBIAR URL)
# git clone https://github.com/YOUR_USERNAME/diagram-generator.git .
# Por ahora, solo crear estructura
mkdir -p backend frontend

# Backend setup
cd backend
npm init -y
npm install express cors dotenv @prisma/client aws-sdk
npm install -D prisma nodemon

# Create .env file (CAMBIAR valores)
cat > .env << 'EOF'
DATABASE_URL="postgresql://diagramadmin:<DB_PASSWORD>@RDS_ENDPOINT:5432/diagramdb"
NODE_ENV="production"
PORT=3000
AWS_REGION="us-east-1"
S3_BUCKET="diagram-generator-ACCOUNT_ID-us-east-1"
EOF

echo "Backend dependencies installed!"
echo "Waiting for RDS to be ready..."

# Try to connect to RDS (wait up to 5 minutes)
for i in {1..60}; do
  if pg_isready -h RDS_ENDPOINT -U diagramadmin &>/dev/null; then
    echo "RDS is ready!"
    break
  fi
  echo "Waiting for RDS... ($i/60)"
  sleep 5
done

echo "Setup complete! Backend ready to start."
```

### 1.3 Ejecutar Terraform

```bash
cd infra

# Inicializar
terraform init
# Output: Terraform has been successfully initialized!

# Ver plan
terraform plan
# Output: Plan: 15 to add, 0 to change, 0 to destroy

# Aplicar cambios (ESTO CREA LOS RECURSOS EN AWS)
terraform apply
# Escribir: yes

# Esperar 5-10 minutos mientras crea recursos...
# Output: Apply complete! Resources: 15 added

# Ver outputs
terraform output

# ANOTAR ESTOS VALORES (NECESARIOS DESPUÉS):
# - backend_public_ip: 3.96.123.45
# - rds_endpoint: diagram-generator-db.c123xyzabc.us-east-1.rds.amazonaws.com
# - s3_bucket_name: diagram-generator-123456789-us-east-1
# - aws_account_id: 123456789
```

**⏸️ PAUSA AQUÍ** - Espera 5 minutos a que RDS esté listo

---

## 🛠️ Paso 2: Crear Backend Node.js (45 min)

### 2.1 Inicializar proyecto backend

```bash
cd backend

# Eliminar package.json que creo Terraform
rm -f package.json package-lock.json

# Crear nuevo
npm init -y

# Instalar dependencias
npm install express cors dotenv @prisma/client aws-sdk
npm install -D prisma nodemon
```

### 2.2 Crear estructura de carpetas

```bash
# En carpeta backend
mkdir -p src/routes src/controllers
mkdir prisma
```

### 2.3 Crear archivo de configuración

**Crear: `backend/.env`**

```
DATABASE_URL="postgresql://diagramadmin:<DB_PASSWORD>@ANOTA_RDS_ENDPOINT:5432/diagramdb"
NODE_ENV="development"
PORT=3000
AWS_REGION="us-east-1"
S3_BUCKET="ANOTA_S3_BUCKET_NAME"
```

**Crear: `backend/.env.example`**

```
DATABASE_URL="postgresql://<USER>:<DB_PASSWORD>@localhost:5432/diagramdb"
NODE_ENV="development"
PORT=3000
AWS_REGION="us-east-1"
S3_BUCKET="your-bucket-name"
```

### 2.4 Crear schema Prisma

**Crear: `backend/prisma/schema.prisma`**

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Project {
  id        String   @id @default(cuid())
  name      String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  diagrams Diagram[]

  @@map("projects")
}

model Diagram {
  id        String   @id @default(cuid())
  name      String
  projectId String
  project   Project  @relation(fields: [projectId], references: [id], onDelete: Cascade)

  components   DiagramComponent[]
  connections  DiagramConnection[]

  mermaidCode String?
  version     Int      @default(1)

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@map("diagrams")
}

model DiagramComponent {
  id        String   @id @default(cuid())
  diagramId String
  diagram   Diagram  @relation(fields: [diagramId], references: [id], onDelete: Cascade)

  name      String
  type      String   // "Frontend", "Backend", "Database", "ExternalService"
  posX      Float    @default(0)
  posY      Float    @default(0)

  createdAt DateTime @default(now())

  connections DiagramConnection[] @relation("from")

  @@map("diagram_components")
}

model DiagramConnection {
  id        String   @id @default(cuid())
  diagramId String
  diagram   Diagram  @relation(fields: [diagramId], references: [id], onDelete: Cascade)

  fromComponentId String
  fromComponent   DiagramComponent @relation("from", fields: [fromComponentId], references: [id], onDelete: Cascade)

  toComponentId String
  label         String?

  createdAt DateTime @default(now())

  @@map("diagram_connections")
}
```

### 2.5 Crear aplicación Express

**Crear: `backend/src/server.js`**

```javascript
require("dotenv").config();
const express = require("express");
const cors = require("cors");
const { PrismaClient } = require("@prisma/client");

const prisma = new PrismaClient();
const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Routes
const diagramRoutes = require("./routes/diagrams");
app.use("/api/diagrams", diagramRoutes);

// Health check
app.get("/health", (req, res) => {
  res.json({ status: "OK", timestamp: new Date() });
});

// Error handling
app.use((err, req, res, next) => {
  console.error("[ERROR]", err.stack);
  res.status(500).json({ error: err.message });
});

// 404
app.use((req, res) => {
  res.status(404).json({ error: "Endpoint not found" });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📊 Diagram Generator Backend`);
  console.log(`Environment: ${process.env.NODE_ENV}`);
});

// Graceful shutdown
process.on("SIGINT", async () => {
  console.log("\nShutting down gracefully...");
  await prisma.$disconnect();
  process.exit(0);
});
```

### 2.6 Crear rutas

**Crear: `backend/src/routes/diagrams.js`**

```javascript
const express = require("express");
const router = express.Router();
const {
  createDiagram,
  getDiagram,
  addComponent,
  addConnection,
  generateMermaid,
  exportDiagram,
} = require("../controllers/diagramController");

router.post("/", createDiagram);
router.get("/:diagramId", getDiagram);
router.post("/:diagramId/components", addComponent);
router.post("/:diagramId/connections", addConnection);
router.get("/:diagramId/mermaid", generateMermaid);
router.post("/:diagramId/export", exportDiagram);

module.exports = router;
```

### 2.7 Crear controlador

**Crear: `backend/src/controllers/diagramController.js`**

```javascript
const { PrismaClient } = require("@prisma/client");
const AWS = require("aws-sdk");

const prisma = new PrismaClient();
const s3 = new AWS.S3({
  region: process.env.AWS_REGION,
});

// Create new diagram
exports.createDiagram = async (req, res) => {
  try {
    const { projectName, diagramName } = req.body;

    if (!projectName || !diagramName) {
      return res
        .status(400)
        .json({ error: "projectName and diagramName required" });
    }

    let project = await prisma.project.findFirst({
      where: { name: projectName },
    });

    if (!project) {
      project = await prisma.project.create({
        data: { name: projectName },
      });
    }

    const diagram = await prisma.diagram.create({
      data: {
        name: diagramName,
        projectId: project.id,
      },
    });

    res.status(201).json(diagram);
  } catch (err) {
    console.error("[ERROR] createDiagram:", err);
    res.status(500).json({ error: err.message });
  }
};

// Get diagram with components and connections
exports.getDiagram = async (req, res) => {
  try {
    const { diagramId } = req.params;

    const diagram = await prisma.diagram.findUnique({
      where: { id: diagramId },
      include: {
        components: true,
        connections: {
          include: {
            fromComponent: true,
          },
        },
      },
    });

    if (!diagram) {
      return res.status(404).json({ error: "Diagram not found" });
    }

    res.json(diagram);
  } catch (err) {
    console.error("[ERROR] getDiagram:", err);
    res.status(500).json({ error: err.message });
  }
};

// Add component to diagram
exports.addComponent = async (req, res) => {
  try {
    const { diagramId } = req.params;
    const { name, type, posX, posY } = req.body;

    if (!name || !type) {
      return res.status(400).json({ error: "name and type required" });
    }

    const component = await prisma.diagramComponent.create({
      data: {
        diagramId,
        name,
        type,
        posX: posX || 0,
        posY: posY || 0,
      },
    });

    res.status(201).json(component);
  } catch (err) {
    console.error("[ERROR] addComponent:", err);
    res.status(500).json({ error: err.message });
  }
};

// Add connection between components
exports.addConnection = async (req, res) => {
  try {
    const { diagramId } = req.params;
    const { fromComponentId, toComponentId, label } = req.body;

    if (!fromComponentId || !toComponentId) {
      return res
        .status(400)
        .json({ error: "fromComponentId and toComponentId required" });
    }

    const connection = await prisma.diagramConnection.create({
      data: {
        diagramId,
        fromComponentId,
        toComponentId,
        label: label || null,
      },
    });

    res.status(201).json(connection);
  } catch (err) {
    console.error("[ERROR] addConnection:", err);
    res.status(500).json({ error: err.message });
  }
};

// Generate Mermaid code
exports.generateMermaid = async (req, res) => {
  try {
    const { diagramId } = req.params;

    const diagram = await prisma.diagram.findUnique({
      where: { id: diagramId },
      include: {
        components: true,
        connections: {
          include: { fromComponent: true },
        },
      },
    });

    if (!diagram) {
      return res.status(404).json({ error: "Diagram not found" });
    }

    let mermaidCode = "graph TB\n";

    // Add components as nodes
    diagram.components.forEach((comp) => {
      const nodeLabel = `${comp.name}<br/>(${comp.type})`;
      mermaidCode += `    ${comp.id}["${nodeLabel}"]\n`;
    });

    // Add connections
    diagram.connections.forEach((conn) => {
      const label = conn.label ? `|${conn.label}|` : "";
      mermaidCode += `    ${conn.fromComponentId} -->${label} ${conn.toComponentId}\n`;
    });

    // Save to database
    await prisma.diagram.update({
      where: { id: diagramId },
      data: { mermaidCode },
    });

    res.json({ mermaidCode, version: diagram.version });
  } catch (err) {
    console.error("[ERROR] generateMermaid:", err);
    res.status(500).json({ error: err.message });
  }
};

// Export diagram to S3
exports.exportDiagram = async (req, res) => {
  try {
    const { diagramId } = req.params;
    const { format } = req.body; // 'mermaid', 'png', 'svg'

    const diagram = await prisma.diagram.findUnique({
      where: { id: diagramId },
    });

    if (!diagram) {
      return res.status(404).json({ error: "Diagram not found" });
    }

    if (!diagram.mermaidCode) {
      return res.status(400).json({ error: "Generate Mermaid code first" });
    }

    const fileName = `${diagramId}-${Date.now()}.${format || "mermaid"}`;
    const params = {
      Bucket: process.env.S3_BUCKET,
      Key: `diagrams/${fileName}`,
      Body: diagram.mermaidCode,
      ContentType: "text/plain",
    };

    await s3.upload(params).promise();

    const s3Url = `https://${process.env.S3_BUCKET}.s3.amazonaws.com/diagrams/${fileName}`;

    res.json({
      url: s3Url,
      fileName,
      format: format || "mermaid",
    });
  } catch (err) {
    console.error("[ERROR] exportDiagram:", err);
    res.status(500).json({ error: err.message });
  }
};
```

### 2.8 Actualizar package.json

**Editar: `backend/package.json`**

```json
{
  "name": "diagram-generator-backend",
  "version": "1.0.0",
  "description": "Backend for Diagram Generator",
  "main": "src/server.js",
  "scripts": {
    "dev": "nodemon src/server.js",
    "start": "node src/server.js",
    "prisma:migrate": "prisma migrate dev",
    "prisma:generate": "prisma generate",
    "prisma:studio": "prisma studio"
  },
  "keywords": [],
  "author": "Sebastian",
  "license": "MIT",
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "@prisma/client": "^5.3.1",
    "aws-sdk": "^2.1400.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1",
    "prisma": "^5.3.1"
  }
}
```

### 2.9 Crear migraciones Prisma

```bash
cd backend

# Generar y ejecutar migraciones
npx prisma migrate dev --name init
# Cuando pregunte el nombre: "init"
# Esto crea las tablas en PostgreSQL

# Verificar que se crearon
npx prisma studio
# Se abre en http://localhost:5555
```

### 2.10 Probar backend

```bash
# En carpeta backend
npm run dev

# Deberías ver:
# 🚀 Server running on port 3000
# 📊 Diagram Generator Backend
# Environment: development

# En otra terminal, probar endpoint
curl http://localhost:3000/health
# Output: {"status":"OK","timestamp":"2024-..."}
```

---

## 🎨 Paso 3: Crear Frontend Angular (1 hora)

### 3.1 Inicializar proyecto Angular

```bash
cd frontend

# Crear proyecto (SI NO EXISTE)
ng new diagram-generator --routing --style=css --skip-git=true

cd diagram-generator

# Instalar Tailwind
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

### 3.2 Configurar Tailwind

**Editar: `frontend/tailwind.config.js`**

```javascript
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{html,ts}"],
  theme: {
    extend: {},
  },
  plugins: [],
};
```

**Editar: `frontend/src/styles.css`**

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family:
    system-ui,
    -apple-system,
    sans-serif;
  background: #f9fafb;
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}
```

### 3.3 Crear servicio

**Crear: `frontend/src/app/services/diagram.service.ts`**

```typescript
import { Injectable } from "@angular/core";
import { HttpClient } from "@angular/common/http";
import { Observable } from "rxjs";

@Injectable({
  providedIn: "root",
})
export class DiagramService {
  private apiUrl = "http://localhost:3000/api/diagrams";

  constructor(private http: HttpClient) {}

  createDiagram(projectName: string, diagramName: string): Observable<any> {
    return this.http.post(`${this.apiUrl}`, {
      projectName,
      diagramName,
    });
  }

  getDiagram(diagramId: string): Observable<any> {
    return this.http.get(`${this.apiUrl}/${diagramId}`);
  }

  addComponent(
    diagramId: string,
    name: string,
    type: string,
    posX: number = 0,
    posY: number = 0,
  ): Observable<any> {
    return this.http.post(`${this.apiUrl}/${diagramId}/components`, {
      name,
      type,
      posX,
      posY,
    });
  }

  addConnection(
    diagramId: string,
    fromComponentId: string,
    toComponentId: string,
    label?: string,
  ): Observable<any> {
    return this.http.post(`${this.apiUrl}/${diagramId}/connections`, {
      fromComponentId,
      toComponentId,
      label,
    });
  }

  generateMermaid(diagramId: string): Observable<any> {
    return this.http.get(`${this.apiUrl}/${diagramId}/mermaid`);
  }

  exportDiagram(diagramId: string, format: string): Observable<any> {
    return this.http.post(`${this.apiUrl}/${diagramId}/export`, {
      format,
    });
  }
}
```

### 3.4 Crear componente form

**Crear: `frontend/src/app/components/component-form/component-form.component.ts`**

```typescript
import { Component, Output, EventEmitter } from "@angular/core";
import { CommonModule } from "@angular/common";
import { FormsModule } from "@angular/forms";

@Component({
  selector: "app-component-form",
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: "./component-form.component.html",
  styleUrls: ["./component-form.component.css"],
})
export class ComponentFormComponent {
  @Output() addComponent = new EventEmitter<{ name: string; type: string }>();

  componentName = "";
  componentType = "Backend";
  componentTypes = ["Frontend", "Backend", "Database", "ExternalService"];

  submit() {
    if (this.componentName.trim()) {
      this.addComponent.emit({
        name: this.componentName,
        type: this.componentType,
      });
      this.componentName = "";
      this.componentType = "Backend";
    }
  }
}
```

**Crear: `frontend/src/app/components/component-form/component-form.component.html`**

```html
<form (ngSubmit)="submit()" class="space-y-3">
  <input
    [(ngModel)]="componentName"
    name="componentName"
    placeholder="Nombre del componente"
    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
  />

  <select
    [(ngModel)]="componentType"
    name="componentType"
    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
  >
    <option *ngFor="let type of componentTypes" [value]="type">
      {{ type }}
    </option>
  </select>

  <button
    type="submit"
    [disabled]="!componentName.trim()"
    class="w-full bg-green-600 text-white py-2 rounded-md hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed font-medium text-sm"
  >
    ➕ Agregar
  </button>
</form>
```

**Crear: `frontend/src/app/components/component-form/component-form.component.css`**

```css
/* Empty - using Tailwind */
```

### 3.5 Crear componente editor

**Crear: `frontend/src/app/components/diagram-editor/diagram-editor.component.ts`**

```typescript
import { Component, OnInit } from "@angular/core";
import { CommonModule } from "@angular/common";
import { FormsModule } from "@angular/forms";
import { DiagramService } from "../../services/diagram.service";
import { ComponentFormComponent } from "../component-form/component-form.component";

@Component({
  selector: "app-diagram-editor",
  standalone: true,
  imports: [CommonModule, FormsModule, ComponentFormComponent],
  templateUrl: "./diagram-editor.component.html",
  styleUrls: ["./diagram-editor.component.css"],
})
export class DiagramEditorComponent implements OnInit {
  projectName = "";
  diagramName = "";
  diagramId: string | null = null;
  components: any[] = [];
  connections: any[] = [];
  mermaidCode = "";
  selectedFromComponent: string | null = null;
  connectionLabel = "";

  componentTypes = ["Frontend", "Backend", "Database", "ExternalService"];

  constructor(private diagramService: DiagramService) {}

  ngOnInit(): void {}

  createDiagram() {
    if (!this.projectName || !this.diagramName) {
      alert("Por favor ingresa nombre de proyecto y diagrama");
      return;
    }

    this.diagramService
      .createDiagram(this.projectName, this.diagramName)
      .subscribe({
        next: (diagram: any) => {
          this.diagramId = diagram.id;
          this.components = [];
          this.connections = [];
          this.mermaidCode = "";
          console.log("✅ Diagram created:", diagram);
        },
        error: (err) => {
          console.error("❌ Error creating diagram:", err);
          alert("Error al crear diagrama: " + err.error?.error || err.message);
        },
      });
  }

  addComponent(event: { name: string; type: string }) {
    if (!this.diagramId) {
      alert("Crea un diagrama primero");
      return;
    }

    const posX = Math.random() * 400;
    const posY = Math.random() * 300;

    this.diagramService
      .addComponent(this.diagramId, event.name, event.type, posX, posY)
      .subscribe({
        next: (component: any) => {
          this.components.push(component);
          console.log("✅ Component added:", component);
        },
        error: (err) => {
          console.error("❌ Error adding component:", err);
          alert("Error: " + err.error?.error);
        },
      });
  }

  selectFromComponent(componentId: string) {
    this.selectedFromComponent =
      this.selectedFromComponent === componentId ? null : componentId;
  }

  connectComponents(toComponentId: string) {
    if (!this.selectedFromComponent || !this.diagramId) return;

    this.diagramService
      .addConnection(
        this.diagramId,
        this.selectedFromComponent,
        toComponentId,
        this.connectionLabel || undefined,
      )
      .subscribe({
        next: (connection: any) => {
          this.connections.push(connection);
          this.connectionLabel = "";
          console.log("✅ Connection added:", connection);
        },
        error: (err) => {
          console.error("❌ Error adding connection:", err);
          alert("Error: " + err.error?.error);
        },
      });
  }

  generateMermaid() {
    if (!this.diagramId) return;

    this.diagramService.generateMermaid(this.diagramId).subscribe({
      next: (result: any) => {
        this.mermaidCode = result.mermaidCode;
        console.log("✅ Mermaid generated");
      },
      error: (err) => {
        console.error("❌ Error generating mermaid:", err);
        alert("Error: " + err.error?.error);
      },
    });
  }

  exportDiagram(format: string) {
    if (!this.diagramId) return;

    this.diagramService.exportDiagram(this.diagramId, format).subscribe({
      next: (result: any) => {
        console.log("✅ Diagram exported:", result);
        window.open(result.url, "_blank");
      },
      error: (err) => {
        console.error("❌ Error exporting:", err);
        alert("Error: " + err.error?.error);
      },
    });
  }

  copyMermaidCode() {
    navigator.clipboard.writeText(this.mermaidCode).then(() => {
      alert("✅ Código copiado al portapapeles");
    });
  }
}
```

**Crear: `frontend/src/app/components/diagram-editor/diagram-editor.component.html`**

```html
<div class="container mx-auto py-8">
  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <!-- LEFT PANEL: Controls -->
    <div class="lg:col-span-1 space-y-4">
      <div class="bg-white p-6 rounded-lg shadow">
        <h2 class="text-lg font-semibold mb-4">📝 Crear Diagrama</h2>

        <div class="space-y-3">
          <input
            [(ngModel)]="projectName"
            placeholder="Nombre del proyecto"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
          />

          <input
            [(ngModel)]="diagramName"
            placeholder="Nombre del diagrama"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
          />

          <button
            (click)="createDiagram()"
            [disabled]="!projectName || !diagramName"
            class="w-full bg-blue-600 text-white py-2 rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed font-medium"
          >
            Crear Diagrama
          </button>
        </div>
      </div>

      <div *ngIf="diagramId" class="bg-white p-6 rounded-lg shadow">
        <h2 class="text-lg font-semibold mb-4">➕ Agregar Componente</h2>
        <app-component-form
          (addComponent)="addComponent($event)"
        ></app-component-form>
      </div>

      <div *ngIf="components.length > 0" class="bg-white p-6 rounded-lg shadow">
        <h3 class="text-sm font-semibold mb-2">
          Componentes ({{ components.length }})
        </h3>
        <div class="space-y-2">
          <div
            *ngFor="let comp of components"
            (click)="selectFromComponent(comp.id)"
            [class.bg-blue-100]="selectedFromComponent === comp.id"
            class="p-2 border rounded cursor-pointer hover:bg-gray-100 text-sm transition"
          >
            {{ comp.name }}
            <span class="text-xs text-gray-500">({{ comp.type }})</span>
          </div>
        </div>
      </div>

      <div *ngIf="selectedFromComponent" class="bg-white p-6 rounded-lg shadow">
        <h3 class="text-sm font-semibold mb-3">Conectar a:</h3>
        <input
          [(ngModel)]="connectionLabel"
          placeholder="Etiqueta (opcional)"
          class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm mb-3 focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
        <div class="space-y-2">
          <button
            *ngFor="let comp of components"
            [disabled]="comp.id === selectedFromComponent"
            (click)="connectComponents(comp.id)"
            [class.opacity-50]="comp.id === selectedFromComponent"
            class="w-full px-2 py-1 bg-green-500 text-white text-sm rounded hover:bg-green-600 disabled:cursor-not-allowed transition font-medium"
          >
            → {{ comp.name }}
          </button>
        </div>
      </div>

      <div *ngIf="diagramId" class="bg-white p-6 rounded-lg shadow">
        <button
          (click)="generateMermaid()"
          class="w-full bg-purple-600 text-white py-2 rounded-md hover:bg-purple-700 text-sm font-medium transition"
        >
          🎨 Generar Diagrama
        </button>
      </div>
    </div>

    <!-- RIGHT PANEL: Canvas & Code -->
    <div class="lg:col-span-2 space-y-4">
      <div class="bg-white p-6 rounded-lg shadow">
        <h2 class="text-lg font-semibold mb-4">📐 Vista Previa</h2>
        <div
          class="bg-gray-100 border-2 border-dashed border-gray-300 rounded p-4 min-h-64 flex items-center justify-center"
        >
          <div class="text-center">
            <p class="text-gray-500 text-sm">
              {{ mermaidCode ? '✅ Diagrama generado exitosamente' : '👇 Genera
              tu diagrama arriba' }}
            </p>
          </div>
        </div>
      </div>

      <div *ngIf="mermaidCode" class="bg-white p-6 rounded-lg shadow">
        <div class="flex justify-between items-center mb-4">
          <h3 class="text-lg font-semibold">Código Mermaid</h3>
          <button
            (click)="copyMermaidCode()"
            class="px-3 py-1 bg-gray-200 text-gray-700 rounded text-sm hover:bg-gray-300 transition font-medium"
          >
            📋 Copiar
          </button>
        </div>
        <pre
          class="bg-gray-900 text-green-400 p-4 rounded text-xs overflow-auto border border-gray-700"
        >
{{ mermaidCode }}</pre
        >

        <div class="mt-4 flex gap-2">
          <button
            (click)="exportDiagram('mermaid')"
            class="flex-1 px-3 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 text-sm transition font-medium"
          >
            📥 Descargar Mermaid
          </button>
        </div>
      </div>

      <div
        *ngIf="connections.length > 0"
        class="bg-white p-6 rounded-lg shadow"
      >
        <h3 class="text-sm font-semibold mb-2">
          Conexiones ({{ connections.length }})
        </h3>
        <div class="text-xs text-gray-600 space-y-1">
          <div *ngFor="let conn of connections">{{ conn.label || '→' }}</div>
        </div>
      </div>
    </div>
  </div>
</div>
```

**Crear: `frontend/src/app/components/diagram-editor/diagram-editor.component.css`**

```css
/* Empty - using Tailwind */
```

### 3.6 Actualizar app.component

**Editar: `frontend/src/app/app.component.ts`**

```typescript
import { Component } from "@angular/core";
import { CommonModule } from "@angular/common";
import { HttpClientModule } from "@angular/common/http";
import { DiagramEditorComponent } from "./components/diagram-editor/diagram-editor.component";

@Component({
  selector: "app-root",
  standalone: true,
  imports: [CommonModule, HttpClientModule, DiagramEditorComponent],
  template: `
    <div class="min-h-screen bg-gray-50">
      <nav class="bg-white shadow">
        <div class="container mx-auto px-4 py-4">
          <h1 class="text-2xl font-bold text-gray-900">📊 Diagram Generator</h1>
          <p class="text-gray-600 text-sm">
            Crea diagramas de arquitectura visualmente
          </p>
        </div>
      </nav>
      <app-diagram-editor></app-diagram-editor>
    </div>
  `,
  styles: [],
})
export class AppComponent {
  title = "diagram-generator";
}
```

**Editar: `frontend/src/main.ts`**

```typescript
import { bootstrapApplication } from "@angular/platform-browser";
import { AppComponent } from "./app/app.component";

bootstrapApplication(AppComponent).catch((err) => console.error(err));
```

### 3.7 Probar frontend

```bash
cd frontend/diagram-generator

ng serve --open
```

Debe abrir http://localhost:4200 automáticamente

---

## 🧪 Paso 4: Testing completo (30 min)

### 4.1 Verificar backend está corriendo

```bash
# Terminal 1 - Backend
cd backend
npm run dev

# Verificar con curl
curl http://localhost:3000/health
```

### 4.2 Verificar frontend está corriendo

```bash
# Terminal 2 - Frontend
cd frontend/diagram-generator
ng serve
```

### 4.3 Crear diagrama de prueba

1. Abrir http://localhost:4200
2. Ingresa:
   - Nombre proyecto: "Mi Proyecto"
   - Nombre diagrama: "Arquitectura v1"
3. Click "Crear Diagrama"
4. Debería habilitar formulario de componentes

### 4.4 Agregar componentes

Agregar 4 componentes:

- Nombre: "Frontend React" | Tipo: "Frontend"
- Nombre: "Backend Node.js" | Tipo: "Backend"
- Nombre: "PostgreSQL" | Tipo: "Database"
- Nombre: "AWS S3" | Tipo: "ExternalService"

### 4.5 Conectar componentes

1. Click "Frontend React"
2. Ingresa label: "REST API"
3. Click "→ Backend Node.js"
4. Repetir con otros

### 4.6 Generar y copiar

1. Click "Generar Diagrama"
2. Debería ver código Mermaid en la derecha
3. Click "Copiar"
4. Pegar en https://mermaid.live para ver visual

---

## 🚀 Paso 5: Deploy en AWS (30 min)

### 5.1 Build frontend

```bash
cd frontend/diagram-generator
ng build --configuration production

# Genera carpeta dist/diagram-generator
```

### 5.2 Subir a EC2

```bash
# Obtener IP de EC2
terraform output backend_public_ip
# Output: 3.96.123.45

# Copiar frontend a EC2
scp -i your-key.pem -r dist/diagram-generator/* \
  ec2-user@3.96.123.45:/tmp/frontend/

# O copiar manualmente vía S3 o Git
```

### 5.3 Verificar disponibilidad

```bash
# En tu navegador
http://3.96.123.45:3000/health
# Debería responder: {"status":"OK",...}

# Si no funciona:
# 1. Esperar 5 minutos (EC2 está initalizando)
# 2. Revisar EC2 está corriendo: aws ec2 describe-instances
# 3. Revisar seguridad: Security groups allow port 3000
```

---

## 📝 Paso 6: Documentación y limpieza (15 min)

### 6.1 Commit a GitHub

```bash
git add .
git commit -m "Initial MVP: Diagram Generator with Terraform + Angular + Node.js"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/diagram-generator.git
git push -u origin main
```

### 6.2 Documentación

- ✅ README.md (YA CREADO)
- ✅ CLAUDE.md (YA CREADO)
- [ ] Crear DEPLOYMENT.md con instrucciones específicas

### 6.3 Anotar información importante

Guardar en lugar seguro:

```
AWS Account ID: xxxxxxxx
EC2 IP: 3.96.123.45
RDS Endpoint: diagram-generator-db.c123xyzabc.us-east-1.rds.amazonaws.com
S3 Bucket: diagram-generator-123456789-us-east-1
DB Username: diagramadmin
DB Password: [TU_PASSWORD]
```

---

## ✅ CHECKLIST FINAL

- [ ] Terraform apply completado
- [ ] EC2 corriendo y accesible
- [ ] RDS creada y accesible desde EC2
- [ ] S3 bucket creado
- [ ] Backend Node.js corriendo localmente
- [ ] Frontend Angular corriendo localmente
- [ ] Full flow funciona: crear → agregar → conectar → generar
- [ ] Código pusheado a GitHub
- [ ] README y CLAUDE.md en repo
- [ ] Información de AWS anotada y segura

---

## 🎯 Próximos pasos (después del MVP)

1. **Nginx en EC2** - servir frontend + API con reverse proxy
2. **HTTPS** - AWS Certificate Manager + ELB
3. **GitHub Actions** - CI/CD automático
4. **Autenticación** - JWT + login
5. **Exportación avanzada** - PNG, SVG con Puppeteer
6. **Versionado** - guardar historial de cambios
7. **Colaboración** - WebSockets para edición real-time
8. **Monitoreo** - CloudWatch dashboards

---

**¡Listo! Ahora solo codear y ejecutar.** 🚀
