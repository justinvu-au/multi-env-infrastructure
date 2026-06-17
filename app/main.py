import os
from fastapi import FastAPI

ENV = os.getenv("ENVIRONMENT", "dev")
VERSION = os.getenv("APP_VERSION", "1.0.0")

app = FastAPI(title=f"PL Infra API [{ENV}]")



@app.get("/")
def root():
    return {
        "message": "Multi-environment infrastructure API",
        "environment": ENV,
        "version": VERSION,
        "status": "healthy"
    }

@app.get("/health")
def health():
    return {
        "status": "healthy",
        "environment": ENV
    }