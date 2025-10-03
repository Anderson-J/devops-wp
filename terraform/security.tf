# Security Group para o Application Load Balancer (ALB)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Permite trafego web de entrada (HTTP)"
  vpc_id      = aws_vpc.main.id

  # Permite entrada na porta 80 (HTTP) de qualquer lugar da internet.
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Libera toda a saída.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg" }
}

# Security Group para as tarefas ECS (conteineres WordPress)
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Regras de firewall para os conteineres da aplicacao"
  vpc_id      = aws_vpc.main.id

  # Permite entrada na porta 8080 (a porta da nossa aplicação)
  # SOMENTE a partir de recursos que estão no security group do nosso ALB.
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Libera toda a saída para a internet (necessário para o NAT Gateway).
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ecs-tasks-sg" }
}

# Security Group para o banco de dados RDS
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Permite acesso ao RDS apenas a partir dos conteineres ECS"
  vpc_id      = aws_vpc.main.id

  # Permite entrada na porta 3306 para o banco de dados SOMENTE a partir de recursos que estão no security group dos contêineres.
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  tags = { Name = "${var.project_name}-rds-sg" }
}

# Security Group para os Mount Targets do EFS
resource "aws_security_group" "efs" {
  name        = "${var.project_name}-efs-sg"
  description = "Permite acesso ao EFS apenas a partir dos conteineres ECS"
  vpc_id      = aws_vpc.main.id

  # Permite entrada na porta 2049 (NFS, protocolo do EFS) SOMENTE a partir de recursos que estão no security group dos contêineres.
  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  tags = { Name = "${var.project_name}-efs-sg" }
}