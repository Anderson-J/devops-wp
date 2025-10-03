# Cria o sistema de arquivos EFS
resource "aws_efs_file_system" "wp_content" {
  creation_token = "${var.project_name}-efs"

  # Modo de performance de propósito geral, ideal para a maioria das cargas de trabalho, incluindo CMS.
  performance_mode = "generalPurpose"

  # Modo de throughput "bursting", onde a performance escala com o tamanho do
  # sistema de arquivos. É o mais custo-efetivo para cargas de trabalho com picos, como sites.
  throughput_mode = "bursting"

  tags = {
    Name = "${var.project_name}-efs"
  }
}

# Política de backup para o EFS, utilizando o serviço AWS Backup.
# Essencial para a proteção de dados em produção.
resource "aws_efs_backup_policy" "wp_content" {
  file_system_id = aws_efs_file_system.wp_content.id
  backup_policy {
    status = "ENABLED" # Habilita os backups automáticos
  }
}

# O EFS precisa de "Mount Targets" para ser acessível de dentro das sub-redes.
# Um mount target em cada sub-rede privada onde nossos contêineres podem rodar.
resource "aws_efs_mount_target" "private_a" {
  file_system_id  = aws_efs_file_system.wp_content.id
  subnet_id       = aws_subnet.private_a.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "private_b" {
  file_system_id  = aws_efs_file_system.wp_content.id
  subnet_id       = aws_subnet.private_b.id
  security_groups = [aws_security_group.efs.id]
}