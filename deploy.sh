#!/bin/bash

# IPTV Panel Deployment Script
# This script sets up a complete IPTV infrastructure with load balancing

set -e

echo "🚀 Starting IPTV Panel Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE} $1 ${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Check if Docker and Docker Compose are installed
check_requirements() {
    print_header "Checking Requirements"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    print_status "Docker and Docker Compose are installed ✓"
}

# Create necessary directories
create_directories() {
    print_header "Creating Directory Structure"
    
    directories=(
        "data/mysql-master"
        "data/mysql-slave" 
        "data/redis"
        "data/grafana"
        "data/prometheus"
        "streams/input"
        "streams/output"
        "streams/hls"
        "streams/dash"
        "streams/recordings"
        "logs/nginx"
        "logs/php1"
        "logs/php2"
        "logs/php3"
        "logs/streaming"
        "nginx/ssl"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        print_status "Created directory: $dir"
    done
    
    # Set proper permissions
    chmod -R 755 data/
    chmod -R 755 streams/
    chmod -R 755 logs/
}

# Configure IPTV Panel
configure_panel() {
    print_header "Configuring IPTV Panel"
    
    # Copy the IPTV panel files to the correct location
    if [ -d "IPTV-Panel" ]; then
        print_status "IPTV Panel source found"
        
        # Create configuration file for database connection
        cat > IPTV-Panel/config/database.php << EOF
<?php
\$config = [
    'master' => [
        'host' => 'db-master',
        'database' => 'iptv_panel',
        'username' => 'iptv_user',
        'password' => 'secure_password_123',
    ],
    'slave' => [
        'host' => 'db-slave',
        'database' => 'iptv_panel',
        'username' => 'iptv_user',
        'password' => 'secure_password_123',
    ],
    'redis' => [
        'host' => 'redis',
        'port' => 6379,
    ]
];
?>
EOF
        
        print_status "Database configuration created"
    else
        print_warning "IPTV-Panel directory not found. Please ensure you have cloned the panel."
    fi
}

# Fix Nginx configuration
fix_nginx_config() {
    print_header "Fixing Nginx Configuration"
    
    # Create proxy_params file
    cat > nginx/proxy_params << EOF
proxy_set_header Host \$http_host;
proxy_set_header X-Real-IP \$remote_addr;
proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto \$scheme;
proxy_connect_timeout 30s;
proxy_send_timeout 30s;
proxy_read_timeout 30s;
proxy_buffering on;
proxy_buffer_size 4k;
proxy_buffers 8 4k;
proxy_busy_buffers_size 8k;
EOF
    
    print_status "Nginx proxy configuration created"
}

# Build and start services
deploy_services() {
    print_header "Building and Starting Services"
    
    # Build custom Docker images
    print_status "Building PHP application image..."
    docker-compose build web1 web2 web3
    
    print_status "Building FFmpeg transcoding image..."
    docker-compose build ffmpeg-transcoder
    
    # Start infrastructure services first
    print_status "Starting infrastructure services..."
    docker-compose up -d db-master redis
    
    # Wait for database to be ready
    print_status "Waiting for database to be ready..."
    sleep 30
    
    # Start slave database
    print_status "Starting slave database..."
    docker-compose up -d db-slave
    
    # Wait for slave to be ready
    sleep 15
    
    # Configure MySQL replication
    configure_replication
    
    # Start web services
    print_status "Starting web services..."
    docker-compose up -d web1 web2 web3
    
    # Start load balancer
    print_status "Starting load balancer..."
    docker-compose up -d nginx-lb
    
    # Start streaming services
    print_status "Starting streaming services..."
    docker-compose up -d streaming-server ffmpeg-transcoder
    
    # Start monitoring services
    print_status "Starting monitoring services..."
    docker-compose up -d prometheus grafana node-exporter
    
    print_status "All services started successfully!"
}

# Configure MySQL replication
configure_replication() {
    print_header "Configuring MySQL Replication"
    
    # Get master status
    print_status "Getting master status..."
    
    # Configure slave
    docker-compose exec -T db-slave mysql -u root -proot_password_123 << EOF
STOP SLAVE;
CHANGE MASTER TO
    MASTER_HOST='db-master',
    MASTER_USER='replication',
    MASTER_PASSWORD='replication_password_123',
    MASTER_AUTO_POSITION=1;
START SLAVE;
EOF
    
    print_status "MySQL replication configured"
}

# Display service information
show_service_info() {
    print_header "Service Information"
    
    echo -e "${GREEN}🌐 Web Services:${NC}"
    echo "  • Main Application: http://localhost"
    echo "  • Load Balancer Status: http://localhost/nginx_status"
    echo ""
    
    echo -e "${GREEN}📺 Streaming Services:${NC}"
    echo "  • Streaming Server: http://localhost:8080"
    echo "  • RTMP Ingest: rtmp://localhost:1935/live"
    echo "  • Stream Statistics: http://localhost:8080/stat"
    echo ""
    
    echo -e "${GREEN}📊 Monitoring:${NC}"
    echo "  • Prometheus: http://localhost:9090"
    echo "  • Grafana: http://localhost:3000 (admin/admin123)"
    echo "  • Node Exporter: http://localhost:9100"
    echo ""
    
    echo -e "${GREEN}🗄️ Databases:${NC}"
    echo "  • MySQL Master: localhost:3306"
    echo "  • MySQL Slave: localhost:3307"
    echo "  • Redis: localhost:6379"
    echo ""
    
    echo -e "${YELLOW}📝 Important Notes:${NC}"
    echo "  • Default IPTV admin: admin/admin (change immediately)"
    echo "  • MySQL root password: root_password_123"
    echo "  • All passwords should be changed in production"
    echo "  • SSL certificates should be configured for HTTPS"
}

# Health check function
health_check() {
    print_header "Running Health Check"
    
    services=("nginx-lb" "web1" "web2" "web3" "db-master" "db-slave" "redis" "streaming-server")
    
    for service in "${services[@]}"; do
        if docker-compose ps | grep -q "$service.*Up"; then
            print_status "$service: ✓ Running"
        else
            print_error "$service: ✗ Not running"
        fi
    done
}

# Performance optimization
optimize_performance() {
    print_header "Applying Performance Optimizations"
    
    # Set kernel parameters for better networking
    echo "Applying kernel optimizations..."
    
    # These would typically go in /etc/sysctl.conf
    cat << EOF
# Network optimizations for high-performance streaming
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_window_scaling = 1
EOF
    
    print_status "Performance optimizations noted (apply to /etc/sysctl.conf)"
}

# Main deployment function
main() {
    print_header "IPTV Panel Deployment Starting"
    
    check_requirements
    create_directories
    configure_panel
    fix_nginx_config
    deploy_services
    optimize_performance
    
    # Wait for services to fully start
    print_status "Waiting for services to fully start..."
    sleep 30
    
    health_check
    show_service_info
    
    print_header "Deployment Complete!"
    
    echo -e "${GREEN}🎉 Your IPTV panel is now ready!${NC}"
    echo -e "${GREEN}🌐 Access your panel at: http://localhost${NC}"
    echo -e "${YELLOW}⚠️  Don't forget to change default passwords!${NC}"
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy"|"start")
        main
        ;;
    "stop")
        print_status "Stopping all services..."
        docker-compose down
        ;;
    "restart")
        print_status "Restarting all services..."
        docker-compose restart
        ;;
    "logs")
        service=${2:-}
        if [ -n "$service" ]; then
            docker-compose logs -f "$service"
        else
            docker-compose logs -f
        fi
        ;;
    "health")
        health_check
        ;;
    "clean")
        print_warning "This will remove all data and containers!"
        read -p "Are you sure? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker-compose down -v
            docker system prune -f
            rm -rf data/ logs/
        fi
        ;;
    *)
        echo "Usage: $0 {deploy|start|stop|restart|logs [service]|health|clean}"
        echo ""
        echo "Commands:"
        echo "  deploy/start - Deploy the IPTV infrastructure"
        echo "  stop         - Stop all services"
        echo "  restart      - Restart all services"
        echo "  logs         - Show logs (optionally for specific service)"
        echo "  health       - Check service health"
        echo "  clean        - Remove all data and containers"
        exit 1
        ;;
esac