-- CreateTable
CREATE TABLE "Project" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "name" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL
);

-- CreateTable
CREATE TABLE "Diagram" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "name" TEXT NOT NULL,
    "projectId" TEXT NOT NULL,
    "mermaidCode" TEXT,
    "version" INTEGER NOT NULL DEFAULT 1,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    CONSTRAINT "Diagram_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "DiagramComponent" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "diagramId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "posX" REAL NOT NULL DEFAULT 0,
    "posY" REAL NOT NULL DEFAULT 0,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "DiagramComponent_diagramId_fkey" FOREIGN KEY ("diagramId") REFERENCES "Diagram" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "DiagramConnection" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "diagramId" TEXT NOT NULL,
    "fromComponentId" TEXT NOT NULL,
    "toComponentId" TEXT NOT NULL,
    "label" TEXT,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "DiagramConnection_diagramId_fkey" FOREIGN KEY ("diagramId") REFERENCES "Diagram" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "DiagramConnection_fromComponentId_fkey" FOREIGN KEY ("fromComponentId") REFERENCES "DiagramComponent" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
