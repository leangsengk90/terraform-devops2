# Python Flask Application

A simple Python web application using Flask framework.

## Features

- Flask web server
- Health check endpoint
- JSON API responses
- Environment configuration
- Docker optimized with multi-stage build

## Endpoints

- `GET /` - Welcome message
- `GET /health` - Health check (required for ALB)
- `GET /api/info` - Application information
- `GET /api/products` - Sample products API
- `GET /metrics` - Application metrics

## Local Development

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run development server
python app.py

# Run with Gunicorn (production)
gunicorn --bind 0.0.0.0:5000 app:app
```

## Docker Build

```bash
# Build locally
docker build -t python-app .

# Run locally
docker run -p 5000:5000 python-app

# Test endpoints
curl http://localhost:5000/health
```

## Environment Variables

- `FLASK_ENV`: Environment (development/production)
- `PORT`: Server port (default: 5000)
- `LOG_LEVEL`: Logging level (default: INFO)
