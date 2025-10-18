const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const compression = require("compression");
const winston = require("winston");

// Configure logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || "info",
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      ),
    }),
  ],
});

const app = express();
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || "development";

// Security middleware
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true }));

// Request logging middleware
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`, {
    method: req.method,
    url: req.path,
    ip: req.ip,
    userAgent: req.get("User-Agent"),
  });
  next();
});

// Routes
app.get("/", (req, res) => {
  res.json({
    message: "Welcome to Docker Swarm Node.js Application!",
    version: "1.0.0",
    environment: NODE_ENV,
    timestamp: new Date().toISOString(),
    hostname: require("os").hostname(),
    uptime: Math.floor(process.uptime()),
  });
});

// Health check endpoint (required for ALB)
app.get("/health", (req, res) => {
  const healthCheck = {
    status: "OK",
    timestamp: new Date().toISOString(),
    uptime: Math.floor(process.uptime()),
    environment: NODE_ENV,
    version: "1.0.0",
    hostname: require("os").hostname(),
    memory: {
      used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
      total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
      external: Math.round(process.memoryUsage().external / 1024 / 1024),
    },
    cpu: {
      user: process.cpuUsage().user,
      system: process.cpuUsage().system,
    },
  };

  res.status(200).json(healthCheck);
});

// API endpoints
app.get("/api/info", (req, res) => {
  res.json({
    application: "Docker Swarm Node.js App",
    version: "1.0.0",
    description: "Sample Node.js application for Docker Swarm deployment",
    author: "DevOps Team Group 4",
    environment: NODE_ENV,
    node_version: process.version,
    platform: process.platform,
    architecture: process.arch,
    timestamp: new Date().toISOString(),
  });
});

// Sample users API
app.get("/api/users", (req, res) => {
  const users = [
    { id: 1, name: "John Doe", email: "john@example.com", role: "admin" },
    { id: 2, name: "Jane Smith", email: "jane@example.com", role: "user" },
    { id: 3, name: "Bob Johnson", email: "bob@example.com", role: "user" },
    {
      id: 4,
      name: "Alice Brown",
      email: "alice@example.com",
      role: "moderator",
    },
  ];

  res.json({
    success: true,
    count: users.length,
    data: users,
    timestamp: new Date().toISOString(),
  });
});

// Sample user by ID
app.get("/api/users/:id", (req, res) => {
  const userId = parseInt(req.params.id);
  const users = [
    { id: 1, name: "John Doe", email: "john@example.com", role: "admin" },
    { id: 2, name: "Jane Smith", email: "jane@example.com", role: "user" },
    { id: 3, name: "Bob Johnson", email: "bob@example.com", role: "user" },
    {
      id: 4,
      name: "Alice Brown",
      email: "alice@example.com",
      role: "moderator",
    },
  ];

  const user = users.find((u) => u.id === userId);

  if (user) {
    res.json({
      success: true,
      data: user,
      timestamp: new Date().toISOString(),
    });
  } else {
    res.status(404).json({
      success: false,
      error: "User not found",
      timestamp: new Date().toISOString(),
    });
  }
});

// Metrics endpoint
app.get("/metrics", (req, res) => {
  const metrics = {
    timestamp: new Date().toISOString(),
    uptime_seconds: Math.floor(process.uptime()),
    memory_usage_mb: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
    memory_total_mb: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
    cpu_usage: process.cpuUsage(),
    node_version: process.version,
    platform: process.platform,
    hostname: require("os").hostname(),
    load_average: require("os").loadavg(),
    free_memory_mb: Math.round(require("os").freemem() / 1024 / 1024),
    total_memory_mb: Math.round(require("os").totalmem() / 1024 / 1024),
  };

  res.json(metrics);
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: "Endpoint not found",
    path: req.path,
    method: req.method,
    timestamp: new Date().toISOString(),
  });
});

// Error handler
app.use((err, req, res, next) => {
  logger.error("Unhandled error:", err);
  res.status(500).json({
    success: false,
    error: NODE_ENV === "production" ? "Internal server error" : err.message,
    timestamp: new Date().toISOString(),
  });
});

// Graceful shutdown
process.on("SIGTERM", () => {
  logger.info("SIGTERM received. Shutting down gracefully...");
  server.close(() => {
    logger.info("Process terminated");
  });
});

process.on("SIGINT", () => {
  logger.info("SIGINT received. Shutting down gracefully...");
  server.close(() => {
    logger.info("Process terminated");
  });
});

// Start server
const server = app.listen(PORT, "0.0.0.0", () => {
  logger.info(`Server running on port ${PORT} in ${NODE_ENV} mode`, {
    port: PORT,
    environment: NODE_ENV,
    hostname: require("os").hostname(),
    timestamp: new Date().toISOString(),
  });
});

module.exports = app;
