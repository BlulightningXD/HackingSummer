from fastapi import FastAPI
from map_database import engine, Base
from routers import complaints_router

# Generate the database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Metro One API")

# Bind your module to the main application
app.include_router(complaints_router.router)

@app.get("/")
def health_check():
    return {"status": "Metro One Backend is running"}