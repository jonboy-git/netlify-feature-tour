FROM alpine:latest

# Install FFmpeg and dependencies
RUN apk update && apk add --no-cache \
    ffmpeg \
    python3 \
    py3-pip \
    curl \
    bash \
    supervisor \
    && rm -rf /var/cache/apk/*

# Install Python packages for monitoring
RUN pip3 install watchdog requests

# Create directories
RUN mkdir -p /scripts /streams/input /streams/output /var/log/supervisor

# Copy scripts
COPY transcode.py /scripts/transcode.py
COPY monitor.py /scripts/monitor.py
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Make scripts executable
RUN chmod +x /scripts/*.py

# Create non-root user
RUN adduser -D -s /bin/bash transcoder

WORKDIR /streams

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]