#!/bin/bash

# IPTV Infrastructure Testing Script
# Verifies that all services are running and responding correctly

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🧪 Testing IPTV Infrastructure Deployment..."

# Test functions
test_service() {
    local service_name=$1
    local url=$2
    local expected_text=$3
    
    echo -n "Testing $service_name... "
    
    if response=$(curl -s --max-time 10 "$url" 2>/dev/null); then
        if [[ -z "$expected_text" ]] || echo "$response" | grep -q "$expected_text"; then
            echo -e "${GREEN}✓ OK${NC}"
            return 0
        else
            echo -e "${RED}✗ FAIL (unexpected response)${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ FAIL (no response)${NC}"
        return 1
    fi
}

test_database() {
    echo -n "Testing MySQL master... "
    if docker-compose exec -T db-master mysql -u iptv_user -psecure_password_123 -e "SELECT 1;" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
    else
        echo -e "${RED}✗ FAIL${NC}"
        return 1
    fi
    
    echo -n "Testing MySQL slave... "
    if docker-compose exec -T db-slave mysql -u iptv_user -psecure_password_123 -e "SELECT 1;" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
    else
        echo -e "${RED}✗ FAIL${NC}"
        return 1
    fi
}

test_redis() {
    echo -n "Testing Redis... "
    if docker-compose exec -T redis redis-cli ping | grep -q PONG; then
        echo -e "${GREEN}✓ OK${NC}"
    else
        echo -e "${RED}✗ FAIL${NC}"
        return 1
    fi
}

test_container_health() {
    echo "📋 Checking container health..."
    
    containers=("nginx-lb" "web1" "web2" "web3" "db-master" "db-slave" "redis" "streaming-server" "prometheus" "grafana")
    
    for container in "${containers[@]}"; do
        echo -n "  $container: "
        if docker-compose ps | grep -q "$container.*Up"; then
            echo -e "${GREEN}Running${NC}"
        else
            echo -e "${RED}Not running${NC}"
        fi
    done
}

# Main testing sequence
echo "🔍 Running comprehensive tests..."
echo

# Container health check
test_container_health
echo

# Service endpoint tests
echo "🌐 Testing web services..."
test_service "Load Balancer" "http://localhost/health" "healthy"
test_service "Nginx Status" "http://localhost/nginx_status" "Active connections"
echo

echo "📺 Testing streaming services..."
test_service "Streaming Server" "http://localhost:8080/health" "streaming-server-healthy"
test_service "RTMP Statistics" "http://localhost:8080/stat" ""
echo

echo "📊 Testing monitoring services..."
test_service "Prometheus" "http://localhost:9090/-/healthy" "Prometheus"
test_service "Grafana" "http://localhost:3000/api/health" "ok"
test_service "Node Exporter" "http://localhost:9100/metrics" "node_"
echo

echo "🗄️ Testing databases..."
test_database
test_redis
echo

# Performance test
echo "⚡ Running basic performance test..."
echo -n "Load balancer response time: "
response_time=$(curl -o /dev/null -s -w "%{time_total}" http://localhost/health)
echo "${response_time}s"

if (( $(echo "$response_time < 1.0" | bc -l) )); then
    echo -e "${GREEN}✓ Response time acceptable${NC}"
else
    echo -e "${YELLOW}⚠ Response time high${NC}"
fi

echo

# Stream test
echo "🎬 Testing streaming capability..."
mkdir -p streams/input

# Create a test video if FFmpeg is available
if command -v ffmpeg &> /dev/null; then
    echo -n "Creating test video... "
    ffmpeg -f lavfi -i testsrc=duration=10:size=320x240:rate=30 -f lavfi -i sine=frequency=1000:duration=10 -c:v libx264 -c:a aac -shortest streams/input/test.mp4 -y >/dev/null 2>&1
    echo -e "${GREEN}✓ Created${NC}"
    
    echo "📁 Test video uploaded to streams/input/test.mp4"
    echo "🔄 Auto-transcoding should begin shortly..."
else
    echo -e "${YELLOW}⚠ FFmpeg not found, skipping video test${NC}"
fi

echo

# Final summary
echo "📈 Infrastructure Status Summary:"
echo "================================="

# Count running services
running_services=$(docker-compose ps | grep "Up" | wc -l)
total_services=10

echo "🚀 Services Running: $running_services/$total_services"

if [ "$running_services" -eq "$total_services" ]; then
    echo -e "${GREEN}🎉 All systems operational!${NC}"
    echo
    echo "🌐 Access Points:"
    echo "  • IPTV Panel: http://localhost"
    echo "  • Monitoring: http://localhost:3000"
    echo "  • Streaming: http://localhost:8080"
    echo
    echo "🔐 Default Credentials:"
    echo "  • IPTV Panel: admin/admin"
    echo "  • Grafana: admin/admin123"
    echo
    echo -e "${YELLOW}⚠️  Remember to change default passwords in production!${NC}"
else
    echo -e "${RED}⚠️  Some services are not running properly${NC}"
    echo "Run './deploy.sh logs' to check for errors"
fi

echo
echo "✅ Testing complete!"