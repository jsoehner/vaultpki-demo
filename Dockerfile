FROM alpine:latest

# Upgrade existing packages to patch vulnerabilities and install necessary utilities
RUN apk upgrade --no-cache && \
    apk add --no-cache bash jq curl docker-cli

# Set working directory
WORKDIR /app

# Copy all demo files into the image
COPY . /app/

# Make setup and helper scripts executable
RUN chmod +x *.sh

# By default, running the container might just drop you to bash
# or run the setup script (assuming the docker socket is mounted)
CMD ["/bin/bash"]
