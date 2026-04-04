# 📊 Diagram Generator

Una aplicación fullstack para crear diagramas de arquitectura visualmente, generar código Mermaid automáticamente y exportar a múltiples formatos. Desplegada en AWS con Terraform como Infrastructure as Code.

## 🎯 Características principales

- ✅ Interfaz visual drag-and-drop para crear componentes
- ✅ Conexiones entre componentes con etiquetas
- ✅ Generación automática de código Mermaid
- ✅ Exportación a múltiples formatos (PNG, SVG, Mermaid)
- ✅ Persistencia en PostgreSQL
- ✅ Almacenamiento en AWS S3
- ✅ Infraestructura reproducible con Terraform
- ✅ Frontend responsivo con Angular + Tailwind CSS

## 📋 Tech Stack

### Frontend
- **Framework:** Angular 17+
- **Estilos:** Tailwind CSS
- **HTTP Client:** HttpClientModule
- **Forms:** ReactiveFormsModule + Standalone Components

### Backend
- **Runtime:** Node.js 18+
- **Framework:** Express.js
- **ORM:** Prisma
- **Base de datos:** PostgreSQL
- **Cloud Storage:** AWS S3

### Infraestructura
- **IaC:** Terraform
- **Cloud Provider:** AWS
- **Servicios:** EC2, RDS, S3, VPC, Security Groups
- **Deployment:** PM2 + GitHub Actions (opcional)

## 🚀 Inicio rápido

### Prerequisitos

```bash
# Instalar Terraform
brew install terraform  # macOS
# O descargar desde: https://www.terraform.io/downloads

# Instalar AWS CLI
brew install awscli

# Instalar Node.js 18+
node --version

# Instalar Angular CLI
npm install -g @angular/cli

# Configurar AWS
aws configure
# Ingresar: Access Key ID, Secret Access Key, region (us-east-1), output (json)
```

### 1️⃣ Setup Infraestructura (Terraform)

```bash
cd infra

# Inicializar Terraform
terraform init

# Ver plan (sin aplicar cambios)
terraform plan

# Aplicar cambios (crear recursos AWS)
terraform apply
# Responder "yes" cuando pregunte

# Obtener outputs (IP de EC2, endpoint de RDS, bucket S3)
terraform output

# Anotar los valores:
# - backend_public_ip: IP pública del EC2
# - rds_endpoint: Endpoint de PostgreSQL
# - s3_bucket_name: Nombre del bucket S3
```

**Nota:** Editar `infra/terraform.tfvars` antes de aplicar:
```hcl
aws_region       = "us-east-1"
allowed_ssh_cidr = "TU_IP/32"        # Cambiar a tu IP
db_username      = "diagramadmin"
db_password      = "REPLACE_WITH_STRONG_PASSWORD"
```

Use a strong, unique password in your local `terraform.tfvars`. Do not commit real secrets.

### 2️⃣ Setup Backend (Node.js)

```bash
cd backend

# Instalar dependencias
npm install

# Crear .env con datos de AWS
cat > .env << EOF
DATABASE_URL="postgresql://diagramadmin:<DB_PASSWORD>@RDS_ENDPOINT:5432/diagramdb"
NODE_ENV="production"
PORT=3000
AWS_REGION="us-east-1"
S3_BUCKET="diagram-generator-ACCOUNT_ID-us-east-1"
EOF

# Ejecutar migraciones Prisma
npx prisma migrate deploy

# Iniciar servidor (desarrollo)
npm run dev

# O producción
npm start
```

### 3️⃣ Setup Frontend (Angular)

```bash
cd frontend

# Instalar dependencias
npm install

# Iniciar servidor de desarrollo
ng serve

# O buildear para producción
ng build --configuration production
```

### 4️⃣ Acceder a la aplicación

```
Frontend: http://localhost:4200 (desarrollo)
Backend API: http://localhost:3000 (desarrollo)
```

## 🏗️ Estructura de carpetas

```
diagram-generator/
│
├── infra/                          # Terraform - Infraestructura AWS
│   ├── main.tf                     # Recursos principales (VPC, EC2, RDS, S3)
│   ├── variables.tf                # Variables de entrada
│   ├── outputs.tf                  # Outputs (IPs, endpoints, etc)
│   ├── user_data.sh               # Script para iniciar backend en EC2
│   └── terraform.tfvars           # Valores de variables (GITIGNORE)
│
├── backend/                        # Node.js/Express API
│   ├── src/
│   │   ├── server.js              # Entry point
│   │   ├── routes/
│   │   │   └── diagrams.js        # Rutas de API
│   │   └── controllers/
│   │       └── diagramController.js # Lógica de negocio
│   ├── prisma/
│   │   └── schema.prisma          # Esquema de BD
│   ├── .env.example               # Variables de entorno
│   ├── package.json
│   └── .gitignore
│
├── frontend/                       # Angular App
│   ├── src/
│   │   ├── app/
│   │   │   ├── components/
│   │   │   │   ├── diagram-editor/
│   │   │   │   └── component-form/
│   │   │   ├── services/
│   │   │   │   └── diagram.service.ts
│   │   │   └── app.component.ts
│   │   ├── styles.css             # Tailwind
│   │   └── main.ts
│   ├── angular.json
│   ├── package.json
│   └── tailwind.config.js
│
├── .github/
│   └── workflows/
│       └── deploy.yml             # GitHub Actions CI/CD
│
├── .gitignore
└── README.md
```

## 📖 Uso de la aplicación

### Crear un diagrama

1. Ingresa nombre del proyecto y diagrama
2. Click en "Crear Diagrama"

### Agregar componentes

1. Selecciona tipo: Frontend, Backend, Database, External Service
2. Ingresa nombre
3. Click "Agregar"

### Conectar componentes

1. Click en un componente para seleccionarlo (se resalta)
2. Ingresa etiqueta de conexión (opcional)
3. Click en componente destino

### Generar y exportar

1. Click "Generar Diagrama" para crear código Mermaid
2. Click "Copiar" para copiar código
3. Click "Descargar" para guardar en S3

## 🔌 API Endpoints

```
POST   /api/diagrams                    # Crear nuevo diagrama
GET    /api/diagrams/:diagramId         # Obtener diagrama con componentes
POST   /api/diagrams/:diagramId/components     # Agregar componente
POST   /api/diagrams/:diagramId/connections   # Agregar conexión
GET    /api/diagrams/:diagramId/mermaid       # Generar código Mermaid
POST   /api/diagrams/:diagramId/export        # Exportar a S3
GET    /health                          # Health check
```

### Ejemplos curl

```bash
# Crear diagrama
curl -X POST http://localhost:3000/api/diagrams \
  -H "Content-Type: application/json" \
  -d '{
    "projectName": "Mi Proyecto",
    "diagramName": "Arquitectura v1"
  }'

# Agregar componente
curl -X POST http://localhost:3000/api/diagrams/{diagramId}/components \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Frontend React",
    "type": "Frontend",
    "posX": 100,
    "posY": 100
  }'

# Agregar conexión
curl -X POST http://localhost:3000/api/diagrams/{diagramId}/connections \
  -H "Content-Type: application/json" \
  -d '{
    "fromComponentId": "{componentId1}",
    "toComponentId": "{componentId2}",
    "label": "REST API"
  }'

# Generar Mermaid
curl http://localhost:3000/api/diagrams/{diagramId}/mermaid

# Health check
curl http://localhost:3000/health
```

## 🗄️ Modelo de datos

### Projects
```
- id (String, primary)
- name (String)
- createdAt (DateTime)
- updatedAt (DateTime)
```

### Diagrams
```
- id (String, primary)
- name (String)
- projectId (String, foreign)
- mermaidCode (String, nullable)
- version (Int)
- createdAt (DateTime)
- updatedAt (DateTime)
```

### DiagramComponents
```
- id (String, primary)
- diagramId (String, foreign)
- name (String)
- type (String: Frontend|Backend|Database|ExternalService)
- posX (Float)
- posY (Float)
- createdAt (DateTime)
```

### DiagramConnections
```
- id (String, primary)
- diagramId (String, foreign)
- fromComponentId (String, foreign)
- toComponentId (String)
- label (String, nullable)
- createdAt (DateTime)
```

## 🌐 Deployment en AWS

### Opción 1: Manual

```bash
# SSH a EC2
ssh -i your-key.pem ec2-user@YOUR_EC2_IP

# En la instancia
cd /opt/diagram-generator/backend
npm start
```

### Opción 2: Automático (GitHub Actions)

1. Pushear a GitHub
2. GitHub Actions ejecuta tests
3. Despliega a EC2 automáticamente
4. Disponible en http://YOUR_EC2_IP

Ver `.github/workflows/deploy.yml` para configurar.

## 📊 Monitoreo

### Logs de aplicación
```bash
# Ver logs en tiempo real
pm2 logs diagram-generator

# Ver todos los procesos
pm2 list
```

### AWS CloudWatch
```bash
# Ver logs de EC2
aws ec2 describe-instances --instance-ids INSTANCE_ID
```

## 🔒 Seguridad

### Variables sensibles
- **Nunca** commitear `.env` con credenciales reales
- Usar `terraform.tfvars` con `.gitignore`
- En producción: usar AWS Secrets Manager o Parameter Store

### HTTPS
Para agregar HTTPS:
```hcl
# En main.tf, agregar ACM certificate
resource "aws_acm_certificate" "main" {
  domain_name = "your-domain.com"
  validation_method = "DNS"
}

# Agregar HTTPS listener en ELB
```

### Security Groups
- SSH: Solo desde tu IP
- HTTP (3000): Abierto para testing, usar HTTPS en prod
- RDS: Solo desde EC2

## ⚡ Optimizaciones

### Frontend
- [ ] Lazy loading de módulos
- [ ] Service workers (offline support)
- [ ] Change detection strategy: OnPush
- [ ] Virtual scrolling para listas grandes

### Backend
- [ ] Caching con Redis
- [ ] Indexing en Prisma queries
- [ ] Rate limiting
- [ ] Compression (gzip)

### Infraestructura
- [ ] Auto-scaling group (EC2)
- [ ] Load balancer (ALB/NLB)
- [ ] RDS read replicas
- [ ] CloudFront CDN para S3

## 🧪 Testing

### Backend
```bash
cd backend
npm test
```

### Frontend
```bash
cd frontend
ng test
```

## 📝 Licencia

MIT

## 👨‍💻 Autor

Sebastian - ITESO Software Engineering Student

## 📞 Soporte

Para issues o preguntas:
1. Revisar logs: `pm2 logs`
2. Verificar estado AWS: `terraform show`
3. Revisar outputs: `terraform output`

## 🎓 Aprendizajes clave

### Terraform
- Infraestructura reproducible
- Estado de recursos (.tfstate)
- Módulos y reutilización
- Outputs para compartir valores

### Angular
- Standalone components
- Services e inyección de dependencias
- HTTP client y observables
- Tailwind CSS

### Node.js + Prisma
- Modelos de datos con ORM
- Migraciones
- Relaciones (1:many, many:many)
- Query optimization

### AWS
- VPC y networking
- Security groups
- EC2 y auto-scaling
- RDS managed database
- S3 object storage
- IAM roles y policies

## 🚀 Próximos pasos

1. **Autenticación:** Agregar JWT + login
2. **Colaboración:** WebSockets para edición en tiempo real
3. **Templates:** Plantillas de arquitecturas comunes
4. **Exportación:** PDF, PNG rendering con Puppeteer
5. **Versioning:** Control de cambios y rollback
6. **CI/CD:** GitHub Actions automático
7. **Monitoreo:** CloudWatch dashboards
8. **Escalado:** Auto-scaling groups + load balancer
