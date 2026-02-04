# Base image
FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive

# Dependency installation
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    curl \
    wget \
    nano \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Cursor CLI (as root)
RUN curl -fsSL https://cursor.com/install | bash

# Add ~/.local/bin to PATH permanently
ENV PATH="/root/.local/bin:${PATH}"

# Workspace
WORKDIR /workspace

CMD ["bash"]
