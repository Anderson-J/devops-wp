# Cria a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  # Habilitar a resolução de DNS para que os serviços possam se comunicar usando nomes DNS dentro da VPC.
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}