FROM python:3-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    shellcheck \
    jq \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install opencode and latest pre-commit
RUN curl -fsSL https://opencode.ai/install | bash && \
    pip install --no-cache-dir --upgrade pip pre-commit

ENV PATH="/root/.opencode/bin:${PATH}"

WORKDIR /workspace
