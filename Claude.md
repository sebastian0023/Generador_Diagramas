# 🤖 CLAUDE.md - Contexto y Instrucciones

Este archivo contiene toda la información necesaria para que Claude ayude en el desarrollo del proyecto **Diagram Generator**.

---

## 📋 Resumen ejecutivo del proyecto

**Diagram Generator** es una aplicación fullstack que permite:

1. Crear diagramas de arquitectura visualmente (drag & drop)
2. Conectar componentes con etiquetas
3. Generar código Mermaid automáticamente
4. Exportar a múltiples formatos (PNG, SVG, Mermaid)
5. Desplegar en AWS con Terraform como Infrastructure as Code

**Objetivo principal:** MVP funcional en 1 mes para proyecto escolar

---

## 🎯 Stack tecnológico FINAL

### Frontend

```
- Angular 17+ (Standalone Components)
- Tailwind CSS
- HttpClientModule
- RxJS para state management básico
```

### Backend

```
- Node.js 18+ + Express
- Prisma ORM
- PostgreSQL (RDS)
- AWS S3 para almacenamiento
```

### Infraestructura

```
- Terraform para IaC
- AWS (EC2, RDS, S3, VPC, Security Groups)
- PM2 para process management
- GitHub Actions para CI/CD (opcional)
```

---

## 📁 Estructura completa del proyecto

```
diagram-generator/
├── infra/                                    # ⭐ Terraform - Capa de infraestructura
│   ├── main.tf                              # Recursos AWS (VPC, EC2, RDS, S3)
│   ├── variables.tf                         # Variables de entrada
│   ├── outputs.tf                           # Outputs (IPs, endpoints)
│   ├── user_data.sh                         # Script de inicialización EC2
│   └── terraform.tfvars                     # GITIGNORE - credenciales
│
├── backend/                                  # ⭐ API Node.js/Express
│   ├── src/
│   │   ├── server.js                        # Entry point
│   │   ├── routes/
│   │   │   └── diagrams.js                  # Definición de rutas
│   │   └── controllers/
│   │       └── diagramController.js         # Lógica: CRUD + Mermaid generation
│   ├── prisma/
│   │   ├── schema.prisma                    # Modelos de BD
│   │   └── migrations/                      # Historial de migraciones
│   ├── .env.example                         # Template de .env
│   ├── .env                                 # GITIGNORE - credenciales reales
│   ├── package.json
│   ├── Dockerfile                           # Para deployar en Docker (opcional)
│   └── .gitignore
│
├── frontend/                                 # ⭐ App Angular + Tailwind
│   ├── src/
│   │   ├── app/
│   │   │   ├── components/
│   │   │   │   ├── diagram-editor/
│   │   │   │   │   ├── diagram-editor.component.ts
│   │   │   │   │   ├── diagram-editor.component.html
│   │   │   │   │   └── diagram-editor.component.css
│   │   │   │   └── component-form/
│   │   │   │       ├── component-form.component.ts
│   │   │   │       ├── component-form.component.html
│   │   │   │       └── component-form.component.css
│   │   │   ├── services/
│   │   │   │   └── diagram.service.ts       # HTTP calls a backend
│   │   │   └── app.component.ts             # Root component
│   │   ├── styles.css                       # Tailwind globals
│   │   └── main.ts
│   ├── angular.json
│   ├── tailwind.config.js
│   ├── package.json
│   ├── tsconfig.json
│   └── .gitignore
│
├── .github/
│   └── workflows/
│       └── deploy.yml                       # GitHub Actions CI/CD (optional)
│
├── .gitignore                               # Node modules, .env, terraform.tfstate, etc.
└── README.md                                # Documentación completa
```

---

## 🔄 Flujo de trabajo

### 1. Crear diagrama (Frontend)

```
Usuario ingresa nombre → Click "Crear" → POST /api/diagrams
↓
Backend crea Project + Diagram en PostgreSQL
↓
Frontend recibe diagramId → UI habilita agregar componentes
```

### 2. Agregar componentes (Frontend → Backend → DB)

```
Usuario ingresa nombre + tipo → Click "Agregar" → POST /api/diagrams/{id}/components
↓
Backend crea DiagramComponent en DB
↓
Frontend actualiza lista local de componentes
```

### 3. Conectar componentes (Frontend → Backend → DB)

```
Usuario selecciona componente → Selecciona destino → POST /api/diagrams/{id}/connections
↓
Backend crea DiagramConnection en DB
↓
Frontend visualiza conexión
```

### 4. Generar Mermaid (Backend)

```
GET /api/diagrams/{id}/mermaid
↓
Backend itera componentes + conexiones
↓
Genera string Mermaid: "graph TB\n..."
↓
Retorna a frontend → Frontend muestra código
```

### 5. Exportar (Backend → S3)

```
POST /api/diagrams/{id}/export con format
↓
Backend sube archivo a S3
↓
Retorna URL pública
↓
Frontend abre en nueva pestaña
```

---

## 🛠️ Comandos esenciales

### Terraform

```bash
cd infra

terraform init          # Primera vez
terraform plan         # Ver qué va a crear
terraform apply        # Crear recursos
terraform output       # Ver IPs/endpoints
terraform destroy      # Destruir (cuidado!)
```

### Backend

```bash
cd backend

npm install                    # Instalar dependencias
npm run dev                   # Desarrollo con nodemon
npm start                     # Producción
npx prisma migrate dev        # Crear/aplicar migraciones
npx prisma studio           # GUI para ver datos
```

### Frontend

```bash
cd frontend

npm install              # Instalar dependencias
ng serve               # Desarrollo (hot reload)
ng build --prod        # Build production
ng test                # Ejecutar tests
```

---

## 📊 Modelo de datos (Prisma Schema)

```prisma
// Users no incluido en MVP - agregar después

model Project {
  id        String   @id @default(cuid())
  name      String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  diagrams  Diagram[]
}

model Diagram {
  id           String   @id @default(cuid())
  name         String
  projectId    String
  project      Project  @relation(fields: [projectId], references: [id], onDelete: Cascade)
  components   DiagramComponent[]
  connections  DiagramConnection[]
  mermaidCode  String?
  version      Int      @default(1)
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
}

model DiagramComponent {
  id        String   @id @default(cuid())
  diagramId String
  diagram   Diagram  @relation(fields: [diagramId], references: [id], onDelete: Cascade)
  name      String
  type      String   // "Frontend" | "Backend" | "Database" | "ExternalService"
  posX      Float    @default(0)
  posY      Float    @default(0)
  createdAt DateTime @default(now())
  connections DiagramConnection[] @relation("from")
}

model DiagramConnection {
  id                String   @id @default(cuid())
  diagramId         String
  diagram           Diagram  @relation(fields: [diagramId], references: [id], onDelete: Cascade)
  fromComponentId   String
  fromComponent     DiagramComponent @relation("from", fields: [fromComponentId], references: [id], onDelete: Cascade)
  toComponentId     String
  label             String?
  createdAt         DateTime @default(now())
}
```

---

## 🔌 API Endpoints (Backend)

### Diagrams

```
POST   /api/diagrams
Body:  { projectName: string, diagramName: string }
Response: { id, name, projectId, createdAt, ... }

GET    /api/diagrams/:diagramId
Response: { id, name, components: [], connections: [] }

POST   /api/diagrams/:diagramId/components
Body:  { name: string, type: string, posX: number, posY: number }
Response: { id, name, type, posX, posY, ... }

POST   /api/diagrams/:diagramId/connections
Body:  { fromComponentId: string, toComponentId: string, label?: string }
Response: { id, fromComponentId, toComponentId, label, ... }

GET    /api/diagrams/:diagramId/mermaid
Response: { mermaidCode: "graph TB\n..." }

POST   /api/diagrams/:diagramId/export
Body:  { format: "mermaid" | "png" | "svg" }
Response: { url: "https://s3.amazonaws.com/...", fileName: "..." }

GET    /health
Response: { status: "OK" }
```

---

## 🌐 Variables de entorno

### Backend (.env)

```
DATABASE_URL=postgresql://user:pass@rds-endpoint:5432/diagramdb
NODE_ENV=production
PORT=3000
AWS_REGION=us-east-1
S3_BUCKET=diagram-generator-ACCOUNT_ID-us-east-1
```

### Frontend (environment.ts)

```typescript
export const environment = {
  production: false,
  apiUrl: "http://localhost:3000/api",
};
```

---

## 🚀 Fases de desarrollo recomendadas

### Fase 1: Setup base (1-2 días)

- [ ] Terraform: VPC + EC2 + RDS + S3
- [ ] Backend: Express + Prisma schema
- [ ] Frontend: Angular project + Tailwind

### Fase 2: Funcionalidad core (3-4 días)

- [ ] Backend: CRUD endpoints para diagrams/components/connections
- [ ] Backend: Generar Mermaid code
- [ ] Frontend: Formularios y canvas básico
- [ ] Frontend: HTTP calls a backend

### Fase 3: Integración (2-3 días)

- [ ] Testear full flow: crear → agregar → conectar → generar
- [ ] Exportación a S3
- [ ] Error handling + validaciones

### Fase 4: Deploy + Polish (2-3 días)

- [ ] Build frontend production
- [ ] Deploy backend a EC2
- [ ] GitHub Actions (opcional)
- [ ] Testing en ambiente real AWS
- [ ] Documentación

---

## ⚠️ Decisiones arquitectónicas clave

### 1. Por qué Standalone Components (Angular)

- Más moderno y recomendado en Angular 17+
- Menos boilerplate que módulos
- Mejor tree-shaking

### 2. Por qué Prisma en lugar de TypeORM

- Mejor DX (Developer Experience)
- Migraciones automáticas
- Type-safe queries
- Compatible con PostgreSQL, MySQL, SQLite

### 3. Por qué Terraform en lugar de CloudFormation

- Language-agnostic (no JSON/YAML)
- Mejor estado management
- Más legible y mantenible
- Funciona con múltiples clouds

### 4. Por qué no agregar autenticación en MVP

- Complejidad extra (JWT, refresh tokens, etc)
- Scope fuera del MVP
- Agregar después: Auth0 o Firebase Auth

### 5. Por qué no WebSockets en MVP

- Complejidad extra
- Colaboración real-time es feature, no MVP
- Agregar después: Socket.io

---

## 🧠 Patrones y convenciones

### Backend (Node.js + Express)

```javascript
// Controller: manejar request, validar, llamar servicio
async function createDiagram(req, res) {
  try {
    const { projectName, diagramName } = req.body;
    // validar
    // crear
    // retornar
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}

// Route: definir endpoint
router.post("/", createDiagram);

// Service (opcional): lógica de negocio reutilizable
async function generateMermaidCode(diagram) {
  // lógica compleja aquí
}
```

### Frontend (Angular)

```typescript
// Component: manejar UI
@Component({
  selector: 'app-diagram-editor',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `...`,
  styleUrls: ['...']
})
export class DiagramEditorComponent {
  components: any[] = [];

  constructor(private diagramService: DiagramService) {}

  addComponent(name: string, type: string) {
    this.diagramService.addComponent(...).subscribe({
      next: (result) => this.components.push(result),
      error: (err) => console.error(err)
    });
  }
}

// Service: abstracción de HTTP
@Injectable({ providedIn: 'root' })
export class DiagramService {
  constructor(private http: HttpClient) {}

  addComponent(diagramId: string, ...): Observable<any> {
    return this.http.post(`${this.apiUrl}/${diagramId}/components`, {...});
  }
}
```

---

## 🐛 Troubleshooting común

### Terraform errors

```
Error: Invalid credentials
→ Revisar: aws configure, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY

Error: Timeout creating EC2
→ Security group bloquea acceso. Revisar ingress rules

Error: RDS endpoint not accessible
→ Security group de RDS debe permitir puerto 5432 desde EC2
```

### Backend errors

```
Error: ENOENT: .env not found
→ Crear .env con variables correctas

Error: Connection refused on port 3000
→ Puerto está en uso: lsof -i :3000 | kill -9

Error: PrismaClientValidationError
→ Schema.prisma tiene errores. Revisar: npx prisma validate
```

### Frontend errors

```
Error: Cannot find module '@angular/core'
→ npm install en carpeta frontend

Error: Cannot GET /api/diagrams
→ Backend no está corriendo, revisar CORS

Error: Tailwind styles no aplicadas
→ Revisar: tailwind.config.js, styles.css imports
```

---

## 📚 Recursos útiles

### Terraform

- [Official Docs](https://www.terraform.io/docs)
- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Best Practices](https://www.terraform.io/docs/language/state)

### Angular

- [Official Docs](https://angular.io/docs)
- [Standalone Components](https://angular.io/guide/standalone-components)
- [Services & DI](https://angular.io/guide/dependency-injection)

### Prisma

- [Official Docs](https://www.prisma.io/docs)
- [Schema Reference](https://www.prisma.io/docs/reference/api-reference/prisma-schema-reference)
- [Migrations](https://www.prisma.io/docs/concepts/components/prisma-migrate)

### AWS

- [EC2 Documentation](https://docs.aws.amazon.com/ec2)
- [RDS Documentation](https://docs.aws.amazon.com/rds)
- [S3 Documentation](https://docs.aws.amazon.com/s3)

---

## 💡 Tips para acelerar desarrollo

### Backend

1. Usar `npm run dev` con nodemon para hot reload
2. Testear endpoints con Postman o curl antes de frontend
3. Usar `npx prisma studio` para ver datos en tiempo real
4. Agregar console.logs para debug (remove después)

### Frontend

1. `ng serve --open` abre navegador automáticamente
2. Usar Angular DevTools extension para debug
3. Abrir DevTools (F12) para ver network + console
4. Usar `ng --version` para verificar Angular version

### AWS/Terraform

1. Usar `terraform plan` antes de `apply` siempre
2. Guardar `terraform.tfstate` en .gitignore
3. Usar outputs para compartir valores (IPs, endpoints)
4. Usar `terraform destroy` para limpiar cuando no uses

---

## 🎯 Métricas de éxito

**MVP funcional cuando:**

- ✅ Puedo crear un diagrama y darle nombre
- ✅ Puedo agregar 5+ componentes de diferentes tipos
- ✅ Puedo conectar componentes con etiquetas
- ✅ Se genera código Mermaid válido
- ✅ Puedo copiar código Mermaid
- ✅ Los datos persisten en PostgreSQL
- ✅ Puedo acceder desde http://AWS_IP en navegador
- ✅ Backend corre en EC2 con PM2
- ✅ Infraestructura creada con Terraform apply
- ✅ Código limpio y documentado en GitHub

**Nice to have después:**

- [ ] Exportación a PNG/SVG
- [ ] Autenticación
- [ ] Colaboración real-time
- [ ] Templates de arquitecturas comunes
- [ ] Versionado de diagramas

---

## 📞 Cómo usar este documento con Claude

**Cuando necesites ayuda:**

1. **Escribir código:** "Crea el componente FormComponent para Angular"
   → Claude tendrá contexto de stack, estructura, patrones

2. **Debug:** "Por qué no conecta el backend con el frontend?"
   → Claude conocerá endpoints, modelos, errores comunes

3. **Arquitectura:** "¿Dónde agrego validaciones?"
   → Claude sugerirá lugares correctos según estructura

4. **Despliegue:** "Cómo configuro CORS en Express?"
   → Claude dará solución correcta para este proyecto

5. **Optimizaciones:** "¿Cómo optimizo queries a RDS?"
   → Claude recomendará Prisma patterns, indexing, etc

---

**Última actualización:** Marzo 2026
**Version:** 1.0
**Status:** MVP Development
