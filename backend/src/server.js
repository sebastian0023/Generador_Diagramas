// Express server - Diagram Generator
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const path = require("path");
require("dotenv").config();

const diagramRoutes = require("./routes/diagrams");

const app = express();
const PORT = process.env.PORT || 3000;

// Security headers
app.use(helmet());

// CORS - restrict to configured origin in production
const allowedOrigin = process.env.CORS_ALLOWED_ORIGIN;
app.use(cors({
  origin: allowedOrigin || "http://localhost:4200",
  methods: ["GET", "POST", "PUT", "DELETE"],
  allowedHeaders: ["Content-Type", "Authorization"],
}));

app.use(express.json());
app.use(express.static(path.join(__dirname, "../public")));

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.use('/api/diagrams', diagramRoutes);

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
