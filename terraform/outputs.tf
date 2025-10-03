output "URL_do_Site_WordPress" {
  description = "URL pública para acessar a instalação do WordPress. Copie e cole este valor no seu navegador."
  value = "http://${aws_lb.main.dns_name}"
}

output "ID_da_VPC_Criada" {
  description = "O ID da VPC (Virtual Private Cloud) provisionada na AWS."
  value = aws_vpc.main.id
}