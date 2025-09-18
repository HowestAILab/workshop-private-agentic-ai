# Dockerfile — extends the Kubeflow codeserver image
ARG BASE_IMAGE=ghcr.io/kubeflow/kubeflow/notebook-servers/codeserver
FROM ${BASE_IMAGE}

COPY requirements.txt .

# Metadata
ENV DEBIAN_FRONTEND=noninteractive

USER root

# Install system packages: python3, pip, git, curl, ca-certificates
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      python3 python3-pip git curl ca-certificates \
      python3-venv \
 && rm -rf /var/lib/apt/lists/*
 
# Install Ollama (official install script)
# (uses Ollama's install script; see https://ollama.com/download)
RUN curl -fsSL https://ollama.com/install.sh | sh
 
# (Optional) Pull llama3.1 into the image by default.
# Remove or comment out the next line if you prefer to pull models at runtime.
# Note: this will download the model during "docker build" and increases image size.
RUN ollama pull llama3.1 || (echo "ollama pull failed — continuing without model" && true)

# Ensure python3 is the default `python` (optional convenience)
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 10 || true

RUN python -m venv /opt/venv && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt
ENV PATH="/opt/venv/bin:$PATH"
 
# Verify basic binaries (kept short)
RUN git --version && python --version && ollama -v || true

# Switch back to jovyan user for Kubeflow compatibility
USER 1000

# Set HOME for Ollama and jovyan user
ENV HOME=/home/jovyan