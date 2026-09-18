"""API FastAPI de exemplo para o projeto "Prova de Fogo: Pipeline CI/CD".

Endpoints:
    GET /health      -> probe de saúde (usado no Healthcheck do Docker e na EC2)
    GET /hello/{nome}-> saudação personalizada

Design decisions:
    - lifespan: executado no startup/desligamento (ex.: abertura de conexões).
    - Response modelo: mantém a resposta do /health estável e versionável,
      que é exatamente o que ferramentas de healthcheck esperam.
"""

from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import FastAPI

from app.config import get_settings


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Ações executadas no ciclo de vida da aplicação.

    Aqui poderíamos conectar ao banco, subir um pool de workers, etc.
    Como reduzimos ao mínimo, apenas registramos o startup no log.
    """
    settings = get_settings()
    print(f"[lifespan] Subindo {settings.app_name} v{settings.app_version}")
    yield
    print("[lifespan] Desligando aplicação")


# A aplicação é criada de forma idempotente e reutilizável:
# isso permite testes e a importação do objeto (ex.: em testes ou em um
# servidor ASGI como Uvicorn) sem duplicar estado.
def create_app() -> FastAPI:
    """Factory da aplicação. Facilita testes que precisam de apps isolados."""
    settings = get_settings()

    application = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        description="API de exemplo para demonstrar um pipeline CI/CD completo.",
        docs_url="/docs",  # Swagger UI disponível por padrão
        redoc_url="/redoc",  # ReDoc alternativo
        lifespan=lifespan,
    )

    @application.get("/health", tags=["health"])
    def health() -> dict[str, str]:
        """Probe de saúde.

        Retorna sempre 200 enquanto a API responde. Use junto com o
        Healthcheck do Docker e com a verificação de vida do Load Balancer
        (ou do systemd, caso rode direto na EC2).
        """
        return {"status": "ok", "version": settings.app_version}

    @application.get("/hello/{nome}", tags=["hello"])
    def hello(nome: str) -> dict[str, str]:
        """Saudação personalizada.

        O parâmetro é validado pelo próprio FastAPI (rota tipada).
        Um nome com caracteres inválidos retorna 422 automaticamente.
        """
        nome_limpo: str = nome.strip().strip('"').strip("'")
        if not nome_limpo:
            # Nome vazio após sanitização é um erro de validação (400).
            from fastapi import HTTPException

            raise HTTPException(status_code=400, detail="Nome não pode ser vazio")
        return {"message": f"Olá, {nome_limpo}! Bem-vindo(a) ao pipeline CI/CD."}

    return application


# Instância padrão usada pelo Uvicorn e importável nos testes.
app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
