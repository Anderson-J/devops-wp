# Recurso do provedor 'random' para gerar uma senha forte e aleatória.
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&'()*+,-./:;<=>?@[]^_`{|}~"
}

# Cria um "segredo" no AWS Secrets Manager.
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.project_name}/db/credentials"
}

# Armazena a versão inicial do segredo (usuário e a senha gerada).
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_password.result
  })
}