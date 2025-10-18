import os
import time
import socket
import logging
from datetime import datetime
from flask import Flask, jsonify, request
import psutil

# Configure logging
logging.basicConfig(
    level=getattr(logging, os.getenv('LOG_LEVEL', 'INFO')),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

app = Flask(__name__)
logger = logging.getLogger(__name__)

# Configuration
PORT = int(os.getenv('PORT', 5000))
ENV = os.getenv('FLASK_ENV', 'production')

# Application start time
START_TIME = time.time()

@app.route('/')
def home():
    """Welcome endpoint"""
    return jsonify({
        'message': 'Welcome to Docker Swarm Python Flask Application!',
        'version': '1.0.0',
        'environment': ENV,
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'hostname': socket.gethostname(),
        'uptime': int(time.time() - START_TIME)
    })

@app.route('/health')
def health():
    """Health check endpoint (required for ALB)"""
    try:
        # Get system metrics
        memory = psutil.virtual_memory()
        cpu_percent = psutil.cpu_percent(interval=0.1)
        
        health_data = {
            'status': 'OK',
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'uptime': int(time.time() - START_TIME),
            'environment': ENV,
            'version': '1.0.0',
            'hostname': socket.gethostname(),
            'memory': {
                'used_mb': round(memory.used / 1024 / 1024, 2),
                'available_mb': round(memory.available / 1024 / 1024, 2),
                'percent': memory.percent
            },
            'cpu': {
                'percent': cpu_percent,
                'count': psutil.cpu_count()
            },
            'disk': {
                'usage_percent': psutil.disk_usage('/').percent
            }
        }
        
        return jsonify(health_data), 200
        
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return jsonify({
            'status': 'ERROR',
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'error': str(e)
        }), 500

@app.route('/api/info')
def api_info():
    """Application information endpoint"""
    return jsonify({
        'application': 'Docker Swarm Python Flask App',
        'version': '1.0.0',
        'description': 'Sample Python Flask application for Docker Swarm deployment',
        'author': 'DevOps Team Group 4',
        'environment': ENV,
        'python_version': f"{psutil.sys.version_info.major}.{psutil.sys.version_info.minor}.{psutil.sys.version_info.micro}",
        'platform': os.name,
        'hostname': socket.gethostname(),
        'timestamp': datetime.utcnow().isoformat() + 'Z'
    })

@app.route('/api/products')
def api_products():
    """Sample products API"""
    products = [
        {'id': 1, 'name': 'Laptop', 'price': 999.99, 'category': 'Electronics'},
        {'id': 2, 'name': 'Smartphone', 'price': 699.99, 'category': 'Electronics'},
        {'id': 3, 'name': 'Book', 'price': 29.99, 'category': 'Education'},
        {'id': 4, 'name': 'Headphones', 'price': 199.99, 'category': 'Electronics'},
        {'id': 5, 'name': 'Coffee Mug', 'price': 12.99, 'category': 'Home'}
    ]
    
    return jsonify({
        'success': True,
        'count': len(products),
        'data': products,
        'timestamp': datetime.utcnow().isoformat() + 'Z'
    })

@app.route('/api/products/<int:product_id>')
def api_product_detail(product_id):
    """Get specific product by ID"""
    products = [
        {'id': 1, 'name': 'Laptop', 'price': 999.99, 'category': 'Electronics', 'description': 'High-performance laptop'},
        {'id': 2, 'name': 'Smartphone', 'price': 699.99, 'category': 'Electronics', 'description': 'Latest smartphone model'},
        {'id': 3, 'name': 'Book', 'price': 29.99, 'category': 'Education', 'description': 'Programming tutorial book'},
        {'id': 4, 'name': 'Headphones', 'price': 199.99, 'category': 'Electronics', 'description': 'Noise-cancelling headphones'},
        {'id': 5, 'name': 'Coffee Mug', 'price': 12.99, 'category': 'Home', 'description': 'Ceramic coffee mug'}
    ]
    
    product = next((p for p in products if p['id'] == product_id), None)
    
    if product:
        return jsonify({
            'success': True,
            'data': product,
            'timestamp': datetime.utcnow().isoformat() + 'Z'
        })
    else:
        return jsonify({
            'success': False,
            'error': 'Product not found',
            'timestamp': datetime.utcnow().isoformat() + 'Z'
        }), 404

@app.route('/metrics')
def metrics():
    """Application metrics endpoint"""
    try:
        memory = psutil.virtual_memory()
        cpu_times = psutil.cpu_times()
        boot_time = psutil.boot_time()
        
        metrics_data = {
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'uptime_seconds': int(time.time() - START_TIME),
            'system_uptime_seconds': int(time.time() - boot_time),
            'memory': {
                'used_mb': round(memory.used / 1024 / 1024, 2),
                'available_mb': round(memory.available / 1024 / 1024, 2),
                'total_mb': round(memory.total / 1024 / 1024, 2),
                'percent': memory.percent
            },
            'cpu': {
                'percent': psutil.cpu_percent(interval=0.1),
                'count': psutil.cpu_count(),
                'user_time': cpu_times.user,
                'system_time': cpu_times.system,
                'idle_time': cpu_times.idle
            },
            'disk': {
                'usage_percent': psutil.disk_usage('/').percent,
                'free_gb': round(psutil.disk_usage('/').free / 1024 / 1024 / 1024, 2),
                'total_gb': round(psutil.disk_usage('/').total / 1024 / 1024 / 1024, 2)
            },
            'network': {
                'hostname': socket.gethostname(),
                'ip_address': socket.gethostbyname(socket.gethostname())
            },
            'load_average': os.getloadavg() if hasattr(os, 'getloadavg') else 'Not available'
        }
        
        return jsonify(metrics_data)
        
    except Exception as e:
        logger.error(f"Metrics collection failed: {str(e)}")
        return jsonify({
            'error': 'Failed to collect metrics',
            'timestamp': datetime.utcnow().isoformat() + 'Z'
        }), 500

@app.errorhandler(404)
def not_found(error):
    """404 error handler"""
    return jsonify({
        'success': False,
        'error': 'Endpoint not found',
        'path': request.path,
        'method': request.method,
        'timestamp': datetime.utcnow().isoformat() + 'Z'
    }), 404

@app.errorhandler(500)
def internal_error(error):
    """500 error handler"""
    logger.error(f"Internal server error: {str(error)}")
    return jsonify({
        'success': False,
        'error': 'Internal server error' if ENV == 'production' else str(error),
        'timestamp': datetime.utcnow().isoformat() + 'Z'
    }), 500

# Request logging middleware
@app.before_request
def log_request_info():
    logger.info(f"{request.method} {request.path} from {request.remote_addr}")

@app.after_request
def log_response_info(response):
    logger.info(f"{request.method} {request.path} - {response.status_code}")
    return response

if __name__ == '__main__':
    logger.info(f"Starting Flask application on port {PORT} in {ENV} mode")
    app.run(host='0.0.0.0', port=PORT, debug=(ENV == 'development'))