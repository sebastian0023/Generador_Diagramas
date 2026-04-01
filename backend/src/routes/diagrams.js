// Diagram routes - Diagram Generator
const express = require('express');
const router = express.Router();
const controller = require('../controllers/diagramController');

router.post('/', controller.createDiagram);
router.get('/:diagramId', controller.getDiagram);
router.post('/:diagramId/components', controller.addComponent);
router.post('/:diagramId/connections', controller.addConnection);
router.get('/:diagramId/mermaid', controller.generateMermaid);
router.post('/:diagramId/export', controller.exportDiagram);

module.exports = router;
