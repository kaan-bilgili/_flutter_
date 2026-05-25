from fastapi import FastAPI, Request
from fastapi.responses import Response

from app.routes.readings import router as readings_router
from app.routes.commands import router as commands_router

app = FastAPI(
    title="ThermoSmart Backend",
    description="Backend API for the ThermoSmart app.",
    version="1.0.0"
)

# Custom CORS middleware — directly injects headers into every response.
# This bypasses CORSMiddleware which can silently fail in some environments.
@app.middleware("http")
async def add_cors_headers(request: Request, call_next):
    # Handle preflight OPTIONS requests immediately
    if request.method == "OPTIONS":
        response = Response(status_code=200)
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "*"
        return response

    response = await call_next(request)
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "*"
    return response

app.include_router(readings_router)
app.include_router(commands_router)

@app.get("/")
def root():
    return {"message": "ThermoSmart backend is running."}

@app.get("/health")
def health_check():
    return {"status": "ok"}