"""Testes da API FastAPI usando pytest + TestClient.

Rodar localmente:
    .venv/bin/pytest

O TestClient usa a lib httpx por baixo; por isso httpx está no requirements.
"""

import pytest
from fastapi.testclient import TestClient

from app.main import create_app


@pytest.fixture
def client() -> TestClient:
    """Fixture: cria um app isolado para cada teste, garantindo o emitido."""
    with TestClient(create_app()) as test_client:
        yield test_client


def test_health_ok(client: TestClient) -> None:
    """GET /health deve responder 200 com status 'ok'."""
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert "version" in body


def test_hello_nome_valido(client: TestClient) -> None:
    """GET /hello/{nome} deve responder 200 e conter o nome na mensagem."""
    nome = "Maria"
    response = client.get(f"/hello/{nome}")
    assert response.status_code == 200
    body = response.json()
    assert "message" in body
    assert "Maria" in body["message"]


def test_hello_nome_com_espacos_e_aspas(client: TestClient) -> None:
    """Nomes com espaços ou aspas extras devem ser tratados."""
    response = client.get('/hello/%22%20Maria%20%22')
    assert response.status_code == 200
    assert "Maria" in response.json()["message"]


def test_hello_nome_vazio_retorna_400(client: TestClient) -> None:
    """Nome vazio após sanitização deve retornar 422/400 (erro controlado)."""
    response = client.get("/hello/   ")
    assert response.status_code in (400, 422)


def test_hello_rota_inexistente_retorna_404(client: TestClient) -> None:
    """Rota desconhecida deve retornar 404, padrão do FastAPI."""
    response = client.get("/rota-que-nao-existe")
    assert response.status_code == 404