#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "🚀 Starting local development environment..."

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not installed"
    exit 1
fi

# Use docker compose or docker-compose based on availability
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# Start services
print_status "Building and starting all services..."
$DOCKER_COMPOSE up --build -d

print_status "Waiting for services to be healthy..."
sleep 10

# Test all services
print_status "Testing services..."

services=(
    "http://localhost:3000|Node.js App"
    "http://localhost:5000|Python App" 
    "http://localhost:8080|Custom Nginx"
    "http://localhost:80|Load Balancer"
)

all_healthy=true

for service in "${services[@]}"; do
    IFS='|' read -r url name <<< "$service"
    
    if curl -sf "$url/health" > /dev/null 2>&1; then
        print_success "$name is healthy ($url)"
    else
        print_error "$name is not responding ($url)"
        all_healthy=false
    fi
done

if [ "$all_healthy" = true ]; then
    print_success "🎉 All services are running successfully!"
    
    echo ""
    print_status "📋 Available endpoints:"
    echo "  • Node.js App:     http://localhost:3000"
    echo "    - Health:        http://localhost:3000/health"
    echo "    - API Info:      http://localhost:3000/api/info"
    echo "    - Users API:     http://localhost:3000/api/users"
    echo ""
    echo "  • Python App:      http://localhost:5000"
    echo "    - Health:        http://localhost:5000/health"
    echo "    - API Info:      http://localhost:5000/api/info"
    echo "    - Products API:  http://localhost:5000/api/products"
    echo ""
    echo "  • Custom Nginx:    http://localhost:8080"
    echo "    - Health:        http://localhost:8080/health"
    echo "    - About Page:    http://localhost:8080/about"
    echo ""
    echo "  • Load Balancer:   http://localhost:80"
    echo "    - Health:        http://localhost:80/health"
    echo "    - Node.js via LB: http://localhost/api/node/"
    echo "    - Python via LB:  http://localhost/api/python/"
    echo ""
    print_status "🔧 Management commands:"
    echo "  • View logs:       $DOCKER_COMPOSE logs -f [service-name]"
    echo "  • Stop services:   $DOCKER_COMPOSE down"
    echo "  • Restart:         $DOCKER_COMPOSE restart [service-name]"
    echo "  • Scale service:   $DOCKER_COMPOSE up --scale nodejs-app=3"
    
else
    print_error "❌ Some services failed to start. Check the logs:"
    echo "  $DOCKER_COMPOSE logs"
    exit 1
fi