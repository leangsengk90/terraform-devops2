FROM nginx:alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy custom HTML content
COPY html/ /usr/share/nginx/html/

# Create custom error pages
RUN echo '<!DOCTYPE html><html><head><title>404 Not Found</title></head><body><h1>404 - Page Not Found</h1><p>The requested page could not be found.</p><a href="/">Go Home</a></body></html>' > /usr/share/nginx/html/404.html

RUN echo '<!DOCTYPE html><html><head><title>Server Error</title></head><body><h1>Server Error</h1><p>An internal server error occurred.</p><a href="/">Go Home</a></body></html>' > /usr/share/nginx/html/50x.html

# Set proper permissions
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]