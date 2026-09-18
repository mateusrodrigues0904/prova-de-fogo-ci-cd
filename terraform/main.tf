# =============================================================================
# Terraform — Provisiona a infraestrutura da EC2 (prova-de-fogo)
#
# Uso:
#   terraform init
#   terraform plan
#   terraform apply   (informe aws_access_key_id e aws_secret_access_key)
#   terraform destroy (descri poeira, economiza free tier)
#
# REQUISITO: uma IAM User na AWS com policy "AmazonEC2FullAccess"
# (em produção, o princípio do menor privilégio vale para tudo — neste
# projeto didático, EC2FullAccess é a única coisa que precisamos).
# =============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # State em disco (local). Em time real você usaria backend remoto (S3 +
  # DynamoDB) para pessoas não sobrescreverem o estado umas das outras.
  backend "local" {}
}

provider "aws" {
  region = var.region
}

# ---------------------------------------------------------------------------
# Security Group: porta 22 (SSH) e 8000 (API)
# ---------------------------------------------------------------------------
resource "aws_security_group" "prova_de_fogo_sg" {
  name        = "prova-de-fogo-sg"
  description = "Libera SSH (22) e API (8000) para o projeto prova-de-fogo"

  ingress {
    description = "SSH para o mundo (autenticacao por chave .pem)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # didatico: em prod restrinja aos IPs do GitHub Actions
  }

  ingress {
    description = "API FastAPI publica"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Saida livre (pull de imagens, apt, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "prova-de-fogo-sg"
  }
}

# ---------------------------------------------------------------------------
# Par de chaves: reutiliza o .pem que voce ja criou no console AWS.
# O caminho do arquivo publico .pub deve existir localmente.
# Gere com:  ssh-keygen -y -f ~/.ssh/prova-de-fogo.pem > ~/.ssh/prova-de-fogo.pub
# ---------------------------------------------------------------------------
resource "aws_key_pair" "prova_de_fogo_key" {
  key_name   = "prova-de-fogo-key"
  public_key = file(var.public_key_path)
}

# ---------------------------------------------------------------------------
# Instância EC2 t2.micro (free tier)
# ---------------------------------------------------------------------------
resource "aws_instance" "prova_de_fogo" {
  ami                    = var.ami # Ubuntu 22.04 LTS por padrao
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.prova_de_fogo_key.key_name
  vpc_security_group_ids = [aws_security_group.prova_de_fogo_sg.id]

  # Docker nao vem instalado de fábrica. Ignore_changes evita que o Terraform
  # reverte mudanças manuais (ex.: docker instalado apos o apply).
  # -> Alternativa profissional: user_data com o script de instalacao do Docker.
  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ubuntu
  EOF

  tags = {
    Name        = "prova-de-fogo-ec2"
    Environment = "homologacao"
    Terraform   = "true"
  }
}

# ---------------------------------------------------------------------------
# Elastic IP: IP publico FIXO (nao muda ao parar/ligar a instancia).
# Com ele, o EC2_HOST do secret GitHub nunca precisa ser atualizado.
# ---------------------------------------------------------------------------
resource "aws_eip" "prova_de_fogo_eip" {
  instance = aws_instance.prova_de_fogo.id
  tags = {
    Name = "prova-de-fogo-eip"
  }
}