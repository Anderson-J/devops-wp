# "Grupo de sub-redes" com as sub-redes privadas.
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# Cria a instância do banco de dados RDS.
resource "aws_db_instance" "main" {
  identifier             = "${var.project_name}-db"
  engine                 = "mariadb"
  engine_version         = "10.6"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20 # 20 GB de armazenamento
  
  db_name                = "wordpress"

  # Puxa o nome de usuário e a senha diretamente do recurso do Secrets Manager
  username               = jsondecode(aws_secretsmanager_secret_version.db_credentials.secret_string)["username"]
  password               = jsondecode(aws_secretsmanager_secret_version.db_credentials.secret_string)["password"]

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Parâmetros importantes para produção:
  multi_az               = false            # Para o lab, `false` economiza custos. Em produção, seria `true`.
  backup_retention_period = 7               # Retém backups por 7 dias.
  publicly_accessible    = false            # Garante que o DB não seja exposto publicamente.
  
  # Importante para laboratórios: permite que o `terraform destroy` delete o banco sem criar um snapshot final. Em produção, o ideal é `false`.
  skip_final_snapshot    = true
}