import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.db import Base, engine
from app.routers import couples, games, users


def create_app() -> FastAPI:
    app = FastAPI(title="Saath API", version="0.1.0")

    # Flutter web runs on a random localhost port during development
    origins = os.getenv("SAATH_CORS_ORIGINS", "*").split(",")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(users.router)
    app.include_router(couples.router)
    app.include_router(games.router)

    @app.get("/health")
    def health():
        return {"ok": True}

    return app


Base.metadata.create_all(engine)
app = create_app()
