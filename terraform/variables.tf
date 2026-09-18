# =============================================================================
# variables.tf — Inputs sensíveis/região-dependentes do Terraform
# =============================================================================

variable "region" {
  description = "Região da AWS onde a infraestrutura será criada"
  type        = string
  default     = "us-east-1"
}

variable "ami" {
  description = "AMI do Ubuntu 22.04 (por região). O default abaixo vale para us-east-1."
  type        = string
  default     = "ami-0e86e20dae9224db8" # Ubuntu 22.04 LTS (us-east-1, amd64)
  # Se provisionar em outra região, busque a AMI atual:
  # aws ec2 describe-images --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" --query 'Images[0].ImageId'
}

variable "public_key_path" {
  description = "Caminho local da chave PUBLICA (.pub) usada na EC2"
  type        = string
  default     = "~/.ssh/prova-de-fogo.pub"
}
