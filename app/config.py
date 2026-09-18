"""Configuração da aplicação via variáveis de ambiente.

Centralizar a configuração aqui tem duas vantagens:
1. Facilita testar (podemos injetar valores diferentes em cada ambiente);
2. É o padrão "Twelve-Factor App": config vive no ambiente, não no código.
"""

import os

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configurações carregadas do ambiente, com valores padrão seguros.

    Ao usar pydantic-settings, qualquer variável de ambiente cujo nome
    corresponda a um atributo (ex.: APP_NAME, APP_VERSION) sobrescreve
    o valor padrão automaticamente.
    """

    app_name: str = "prova-de-fogo-fastapi"
    app_version: str = "1.0.0"
    # debug_flag? Evite! Em produção debug=True é um risco de segurança.
    # Uma melhor prática é expor uma flag "environment" (dev/prod).
    environment: str = "production"

    model_config = SettingsConfigDict(env_file=".env", env_prefix="APP_", extra="ignore")


def get_settings() -> Settings:
    """Retorna as configurações (cache simples para evitar recarregar o .env)."""
    return get_settings.cache if hasattr(get_settings, "cache") else _load_settings()


def _load_settings() -> Settings:
    get_settings.cache = Settings()
    return get_settings.cache