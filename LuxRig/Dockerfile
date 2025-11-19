# LuxRig Production Docker Image
FROM mcr.microsoft.com/powershell:latest

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy LuxRig files
COPY . /app/

# Create necessary directories
RUN mkdir -p /app/Data /app/Logs /app/Configs

# Install PowerShell modules
RUN pwsh -Command "Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser"

# Set environment
ENV LUXRIG_ENV=production
ENV LUXRIG_DATA_PATH=/app/Data

# Expose ports
EXPOSE 8080

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD pwsh -Command "Test-Path /app/Data/luxrig.db"

# Entry point
ENTRYPOINT ["pwsh", "-File", "/app/START-LUXRIG.ps1"]
