# Custom Nginx Application

A custom Nginx web server with static content and optimized configuration.

## Features

- Nginx with custom static content
- Optimized nginx.conf for production
- Health check endpoint
- Custom error pages
- Security headers
- Gzip compression
- Docker optimized

## Endpoints

- `GET /` - Custom homepage
- `GET /health` - Health check (required for ALB)
- `GET /about` - About page
- `GET /api/status` - Server status (JSON)

## Local Development

```bash
# Build and run with Docker
docker build -t nginx-custom .
docker run -p 80:80 nginx-custom

# Test endpoints
curl http://localhost/
curl http://localhost/health
```

## Configuration

- **Port**: 80
- **Health Check Path**: `/health`
- **Static Content**: Custom HTML pages
- **Security**: Security headers enabled
- **Compression**: Gzip enabled for text files
