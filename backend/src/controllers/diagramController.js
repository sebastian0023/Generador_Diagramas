// Diagram controller - Diagram Generator
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function createDiagram(req, res) {
  try {
    const { projectName, diagramName } = req.body;

    const project = await prisma.project.create({
      data: {
        name: projectName,
        diagrams: {
          create: { name: diagramName }
        }
      },
      include: { diagrams: true }
    });

    res.json(project.diagrams[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}

async function getDiagram(req, res) {
  try {
    const diagram = await prisma.diagram.findUnique({
      where: { id: req.params.diagramId },
      include: { components: true, connections: true }
    });

    if (!diagram) return res.status(404).json({ error: 'Diagram not found' });
    res.json(diagram);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}

async function addComponent(req, res) {
  try {
    const { name, type, posX, posY } = req.body;

    const component = await prisma.diagramComponent.create({
      data: {
        diagramId: req.params.diagramId,
        name,
        type,
        posX: posX || 0,
        posY: posY || 0
      }
    });

    res.json(component);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}

async function addConnection(req, res) {
  try {
    const { fromComponentId, toComponentId, label } = req.body;

    const connection = await prisma.diagramConnection.create({
      data: {
        diagramId: req.params.diagramId,
        fromComponentId,
        toComponentId,
        label
      }
    });

    res.json(connection);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}

async function generateMermaid(req, res) {
  try {
    const diagram = await prisma.diagram.findUnique({
      where: { id: req.params.diagramId },
      include: { components: true, connections: true }
    });

    if (!diagram) return res.status(404).json({ error: 'Diagram not found' });

    let mermaid = 'graph TB\n';

    const typeShapes = {
      Frontend: ['[/', '/]'],
      Backend: ['[', ']'],
      Database: ['[(', ')]'],
      ExternalService: ['((', '))']
    };

    for (const comp of diagram.components) {
      const shape = typeShapes[comp.type] || ['[', ']'];
      mermaid += `  ${comp.id}${shape[0]}${comp.name}${shape[1]}\n`;
    }

    for (const conn of diagram.connections) {
      const label = conn.label ? `|${conn.label}|` : '';
      mermaid += `  ${conn.fromComponentId} -->|${conn.label || ''}| ${conn.toComponentId}\n`;
    }

    await prisma.diagram.update({
      where: { id: req.params.diagramId },
      data: { mermaidCode: mermaid }
    });

    res.json({ mermaidCode: mermaid });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}

async function exportDiagram(req, res) {
  try {
    const { format } = req.body;
    const diagram = await prisma.diagram.findUnique({
      where: { id: req.params.diagramId },
      include: { components: true, connections: true }
    });

    if (!diagram) return res.status(404).json({ error: 'Diagram not found' });

    if (format === 'mermaid') {
      res.json({
        fileName: `${diagram.name}.mmd`,
        content: diagram.mermaidCode || 'No mermaid code generated yet'
      });
    } else {
      res.status(400).json({ error: 'For MVP only mermaid format is supported' });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}

module.exports = {
  createDiagram,
  getDiagram,
  addComponent,
  addConnection,
  generateMermaid,
  exportDiagram
};
