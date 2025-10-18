# Node.js Express Application

A simple Node.js web application using Express.js framework.

## Features

- Express.js web server
- Health check endpoint
- JSON API responses
- Environment configuration
- Docker optimized

## Endpoints

- `GET /` - Welcome message
- `GET /health` - Health check (required for ALB)
- `GET /api/info` - Application information
- `GET /api/users` - Sample users API

## Local Development

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Start production server
npm start
```

## Docker Build

```bash
# Build locally
docker build -t nodejs-app .

# Run locally
docker run -p 3000:3000 nodejs-app

# Test endpoints
curl http://localhost:3000/health
```

## Environment Variables

- `NODE_ENV`: Environment (development/production)
- `PORT`: Server port (default: 3000)
- `LOG_LEVEL`: Logging level (default: info)
