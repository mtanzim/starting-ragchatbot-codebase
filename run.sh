#!/bin/bash

# Startup script for the RAG Course Materials Chatbot
# This script sets up the environment and starts the FastAPI server

# Create necessary directories
# The 'docs' directory is where course material files are loaded from
# -p flag ensures no error if directory already exists
mkdir -p docs

# Check if backend directory exists
# This validation ensures we're running from the correct project root
if [ ! -d "backend" ]; then
    echo "Error: backend directory not found"
    exit 1
fi

echo "Starting Course Materials RAG System..."
echo "Make sure you have set your ANTHROPIC_API_KEY in .env"

# Change to backend directory and start the server
# --reload: Auto-restart server on code changes (development mode)
# --port 8000: Server will be accessible at http://localhost:8000
cd backend && uv run uvicorn app:app --reload --port 8000