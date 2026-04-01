// Express server - Diagram Generator
const express = require("express");
const cors = require("cors");
require("dotenv").config();

const diagramRoutes = require("./routes/diagrams");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
    res.json({ status: 'ok' });
});

app.use('/api/diagrams', diagramRoutes);

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});