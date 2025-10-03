resource "aws_cloudwatch_log_group" "ecs_wordpress" {
  name = "/ecs/${var.project_name}/wordpress"

  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-log-group"
  }
}