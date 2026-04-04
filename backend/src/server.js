// Express server - Diagram Generator
const express = require("express");
const cors = require("cors");
const path = require("path");
require("dotenv").config();

const diagramRoutes = require("./routes/diagrams");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, "../public")));

app.get('/health', (req, res) => {
    res.json({ status: 'ok' });
});

app.use('/api/diagrams', diagramRoutes);

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});