# =============================================================================
# outputs.tf — Endereços úteis após o terraform apply
# =============================================================================

output "instance_id" {
  description = "ID da instância EC2"
  value       = aws_instance.prova_de_fogo.id
}

output "instance_public_ip" {
  description = "IP público (dinâmico) da instância"
  value       = aws_instance.prova_de_fogo.public_ip
}

output "elastic_ip" {
  description = "IP público FIXO (Elastic IP) — use este no secret EC2_HOST"
  value       = aws_eip.prova_de_fogo_eip.public_ip
}

output "api_url" {
  description = "URL da API em produção"
  value       = "http://${aws_eip.prova_de_fogo_eip.public_ip}:8000/health"
}