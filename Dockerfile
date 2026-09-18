# =============================================================================
# Dockerfile — Multi-stage build para a API FastAPI "Prova de Fogo"
#
# Por que multi-stage?
#   Uma única imagem final, SEM ferramentas de build (compiladores, pip
#   sendo "matando" caches, cmake, etc). Menos superfície de ataque e
#   imagem muito menor (de ~1GB para ~150MB com slim).
#
# Estágios:
#   1. builder  -> instala dependências Python num venv limpo
#   2. runtime  -> copia SOMENTE o venv e o código da aplicação
# =============================================================================

# -----------------------------------------------------------------------------
# ESTÁGIO 1 — BUILDER
# -----------------------------------------------------------------------------
# python:3.11-slim: Debian slim (~120MB) em vez de "full", que é ~1GB.
# 3.11 porque libs como pydantic-core têm wheels prontos (build rápido e
# estável). A tag "slim" mantém glibc (libc do Debian) — compatível com
# quase todo software; "alpine" usaria musl e exigiria compilação de wheels
# nativos (mais lento e mais frágil no build). Para júnior: slim > alpine.
FROM python:3.11-slim AS builder

# PYTHONDONTWRITEBYTECODE=1 -> não criar __pycache__ na imagem (mais leve).
# PYTHONUNBUFFERED=1        -> logs saem em tempo real (sem buffer) — essencial
#                             para debugar no "docker logs" e para kubectl logs.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Instala o build-base? NÃO — wheels universais suficientes.
# Cria o venv "deploy" onde tudo (runtime) será instalado.
RUN python -m venv /opt/venv

# "ENV PATH" para que o venv seja o interpretador padrão em todos os estágios
# seguintes. Isso evita digitar /opt/venv/bin/pip em todo comando.
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app

# Copia SÓ o requirements primeiro: o Docker cacheia esta camada e só a
# recria quando requirements.txt muda. Resultado: builds seguentes quase
# instantâneos quando o código muda sem tocar nas dependências.
COPY requirements.txt .

# Instala as dependências de PRODUÇÃO dentro do venv.
# pip 23+ já não tem o --no-cache-dir como obrigatório por segurança — usamos
# --no-cache-dir para reduzir o tamanho da imagem em ~30-60MB.
# Ao final, DESINSTALA pip/setuptools/wheel do venv: são ferramentas de build,
# não existem em runtime de produção. Além de enxugar a imagem, remove os
# pacotes vendored do pip (ex.: msgpack) dos findings do Trivy.
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt \
    && pip uninstall -y pip setuptools wheel

# -----------------------------------------------------------------------------
# ESTÁGIO 2 — RUNTIME
# -----------------------------------------------------------------------------
FROM python:3.11-slim AS runtime

# Variáveis de ambiente do runtime (mesmas lógicas do builder).
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    APP_ENVIRONMENT=production \
    APP_NAME=prova-de-fogo-fastapi

# Patches de segurança do Debian acima da imagem base.
# Ex.: CVEs de gzip/perl/libpcre2/libsqlite3 com correção disponivel apenas
# via apt (a imagem publicada pode estar dias desatualizada). Isso furando a
# imutabilidade é compensado pela redução real do risco — padrão comum em
# times de segurança de containers. Depois de `apt upgrade`, limpamos o cache
# para não inflar a imagem.
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Remove o site-packages do base image (/usr/local) INTEIRO: o venv /opt/venv
# é autossuficiente (pip/setuptools/wheel próprios e atualizados).
# O pip 24.0 vendora msgpack (falso-positivo do Trivy) e nada disso é usado
# em produção. Menos pacotes = menos superfície e imagem menor.
RUN rm -rf /usr/local/lib/python3.11/site-packages

# Cria um usuário sem privilégios: se a aplicação for comprometida, o atacante
# NÃO tem acesso de root dentro do container (defesa em profundidade).
# O usuário "app" tem UID 10001 (não 1000) para não conflitar com o usuário
# host 1000 em binds de volume (ex.: CI rodando com UID 1000).
RUN useradd --create-home --shell /bin/false --uid 10001 appuser \
    && mkdir -p /app

WORKDIR /app

# Copia o venv completo do builder para o runtime.
COPY --from=builder /opt/venv /opt/venv

# Copia o código da aplicação. O "." final é o build context (~/repo).
# O .dockerignore (criado na mesma etapa) impede que venv/.git/etc
# entrem na imagem.
COPY --chown=10001:10001 app ./app

# Healthcheck: o Docker pergunta à API se ela está viva a cada 30s.
# Na EC2, o systemd/compose também consideram isso para reiniciar o
# container caso ele fique inacessível.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"

# Passa a rodar como o usuário não-root.
USER appuser

# Porta exposta (não PUBLICA, é documentacional — quem expõe é o -p host:8000).
EXPOSE 8000

# Comando de inicialização: uvicorn escuta 0.0.0.0 para ser acessível de fora
# (na EC2 recebe tráfego do Security Group/saída do reverse proxy).
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
