# Cria um Cluster ECS
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

# ROLE DE EXECUÇÃO (PARA O AGENTE ECS INICIAR A TAREFA)
data "aws_iam_policy_document" "ecs_task_execution_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.project_name}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# PERMISSÕES PARA O SECRETS MANAGER
data "aws_iam_policy_document" "task_secrets_policy_doc" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.db_credentials.arn]
  }
}

resource "aws_iam_policy" "task_secrets_policy" {
  name   = "${var.project_name}-task-secrets-policy"
  policy = data.aws_iam_policy_document.task_secrets_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "task_secrets_policy_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.task_secrets_policy.arn
}

resource "aws_ecs_task_definition" "wordpress" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512    # 0.5 vCPU
  memory                   = 1024   # 1 GB de Memória
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  volume {
    name = "wp-content-efs"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.wp_content.id
    }
  }

  container_definitions = jsonencode([
    {
      name      = "wordpress-app"
      image     = "anderaoliv/wordpress-pt_br:main"
      cpu       = 512
      memory    = 1024
      essential = true
      portMappings = [
        { containerPort = 8080, protocol = "tcp" }
      ]
      mountPoints = [
        {
          sourceVolume  = "wp-content-efs"
          containerPath = "/var/www/html/wp-content"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_wordpress.name,
          "awslogs-region"        = var.aws_region,
          "awslogs-stream-prefix" = "ecs"
        }
      }
      environment = [
        { name = "WORDPRESS_DB_HOST", value = aws_db_instance.main.address },
        { name = "WORDPRESS_DB_NAME", value = "wordpress" }
      ]
      secrets = [
        { name = "WORDPRESS_DB_USER", valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:username::" },
        { name = "WORDPRESS_DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:password::" }
      ]
    }
  ])
}

# SERVIÇO ECS
resource "aws_ecs_service" "main" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.wordpress.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = 120
  force_new_deployment              = true

  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "wordpress-app"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.http]
}