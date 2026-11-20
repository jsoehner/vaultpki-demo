ARG BASE_IMAGE=alpine:latest
FROM ${BASE_IMAGE}

# Upgrade existing packages to patch vulnerabilities and install necessary utilities
RUN apk upgrade --no-cache && \
    apk add --no-cache bash jq curl docker-cli

# Set working directory
WORKDIR /app

# Copy all demo files into the image
COPY . /app/

# Make setup and helper scripts executable and switch to non-root user
RUN chmod +x *.sh scripts/pki/*.sh scripts/bom/*.sh && \
    adduser -D -u 1001 appuser && \
    chown -R appuser:appuser /app

USER appuser

# By default, running the container might just drop you to bash
# or run the setup script (assuming the docker socket is mounted)
CMD ["/bin/bash"]
