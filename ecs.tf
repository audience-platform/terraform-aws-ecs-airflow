resource "aws_cloudwatch_log_group" "airflow" {
  name              = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  retention_in_days = var.airflow_log_retention

  tags = local.common_tags
}

resource "aws_ecs_cluster" "airflow" {
  name               = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  tags = local.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "airflow" {
  cluster_name = aws_ecs_cluster.airflow.name

  capacity_providers = ["FARGATE_SPOT", "FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
  }
}

resource "aws_ecs_task_definition" "airflow" {
  family                   = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  network_mode             = "awsvpc"
  task_role_arn            = aws_iam_role.task.arn
  execution_role_arn       = aws_iam_role.execution.arn

  # HACK: fix for bug in aws_ecs_task_definition provider
  # lifecycle {
  #   ignore_changes = [ container_definitions ]
  # }

  container_definitions = <<TASK_DEFINITION
    [
      {
        "image": "mikesir87/aws-cli",
        "name": "${local.airflow_sidecar_container_name}",
        "command": [
            "/bin/bash -c \"aws s3 cp s3://${local.s3_bucket_name}/${local.s3_key} ${var.airflow_container_home} --recursive && chmod +x ${var.airflow_container_home}/${aws_s3_object.airflow_scheduler_entrypoint.key} && chmod +x ${var.airflow_container_home}/${aws_s3_object.airflow_webserver_entrypoint.key} && chmod +x ${var.airflow_container_home}/${aws_s3_object.airflow_init_entrypoint.key} && chmod 777 ${var.airflow_container_home}\""
        ],
        "entryPoint": [
            "sh",
            "-c"
        ],
        "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
            "awslogs-group": "${aws_cloudwatch_log_group.airflow.name}",
            "awslogs-region": "${local.airflow_log_region}",
            "awslogs-stream-prefix": "airflow"
          }
        },
        "essential": false,
        "mountPoints": [
          {
            "sourceVolume": "${local.airflow_volume_name}",
            "containerPath": "${local.efs_root_directory}",
            "readOnly": false
          }
        ]
      },
      {
        "image": "${var.airflow_image_name}:${var.airflow_image_tag}",
        "name": "${local.airflow_init_container_name}",
        "dependsOn": [
            {
                "containerName": "${local.airflow_sidecar_container_name}",
                "condition": "SUCCESS"
            }
        ],
        "command": [
            "/bin/bash -c \"${var.airflow_container_home}/${aws_s3_object.airflow_init_entrypoint.key}\""
        ],
        "entryPoint": [
            "sh",
            "-c"
        ],
        "environment": [
          ${join(",\n", formatlist("{\"name\":\"%s\",\"value\":\"%s\"}", keys(local.airflow_variables), values(local.airflow_variables)))}
        ],
        "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
            "awslogs-group": "${aws_cloudwatch_log_group.airflow.name}",
            "awslogs-region": "${local.airflow_log_region}",
            "awslogs-stream-prefix": "airflow"
          }
        },
        "essential": false,
        "mountPoints": [
          {
            "sourceVolume": "${local.airflow_volume_name}",
            "containerPath": "${local.efs_root_directory}",
            "readOnly": false
          }
        ]
      },
      {
        "image": "${var.airflow_image_name}:${var.airflow_image_tag}",
        "name": "${local.airflow_scheduler_container_name}",
        "dependsOn": [
            {
                "containerName": "${local.airflow_sidecar_container_name}",
                "condition": "SUCCESS"
            },
            {
                "containerName": "${local.airflow_init_container_name}",
                "condition": "SUCCESS"
            }
        ],
        "command": [
            "/bin/bash -c \"${var.airflow_container_home}/${aws_s3_object.airflow_scheduler_entrypoint.key}\""
        ],
        "entryPoint": [
            "sh",
            "-c"
        ],
        "environment": [
          ${join(",\n", formatlist("{\"name\":\"%s\",\"value\":\"%s\"}", keys(local.airflow_variables), values(local.airflow_variables)))}
        ],
        "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
            "awslogs-group": "${aws_cloudwatch_log_group.airflow.name}",
            "awslogs-region": "${local.airflow_log_region}",
            "awslogs-stream-prefix": "airflow"
          }
        },
        "essential": true,
        "mountPoints": [
          {
            "sourceVolume": "${local.airflow_volume_name}",
            "containerPath": "${local.efs_root_directory}",
            "readOnly": false
          }
        ]
      },
      {
        "image": "${var.airflow_image_name}:${var.airflow_image_tag}",
        "name": "${local.airflow_webserver_container_name}",
        "dependsOn": [
            {
                "containerName": "${local.airflow_sidecar_container_name}",
                "condition": "SUCCESS"
            },
            {
                "containerName": "${local.airflow_init_container_name}",
                "condition": "SUCCESS"
            }
        ],
        "command": [
            "/bin/bash -c \"${var.airflow_container_home}/${aws_s3_object.airflow_webserver_entrypoint.key}\""
        ],
        "entryPoint": [
            "sh",
            "-c"
        ],
        "environment": [
          ${join(",\n", formatlist("{\"name\":\"%s\",\"value\":\"%s\"}", keys(local.airflow_variables), values(local.airflow_variables)))}
        ],
        "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
            "awslogs-group": "${aws_cloudwatch_log_group.airflow.name}",
            "awslogs-region": "${local.airflow_log_region}",
            "awslogs-stream-prefix": "airflow"
          }
        },
        "healthCheck": {
          "command": [ "CMD-SHELL", "curl -f http://0.0.0.0:8080/health || exit 1" ],
          "startPeriod": 120
        },
        "essential": true,
        "mountPoints": [
          {
            "sourceVolume": "${local.airflow_volume_name}",
            "containerPath": "${local.efs_root_directory}",
            "readOnly": false
          }
        ],
        "portMappings": [
            {
                "containerPort": 8080,
                "hostPort": 8080
            }
        ]
      }
    ]
  TASK_DEFINITION

  volume {
    name = "${local.airflow_volume_name}"
    efs_volume_configuration {
        file_system_id = "${aws_efs_file_system.airflow-efs.id}"
        root_directory = "/"
      # HACK: fix for bug in aws_ecs_task_definition provider
        transit_encryption = "ENABLED"
        transit_encryption_port = 7777
    }
  }

  tags = local.common_tags
}


// Without depends_on I get this error:
// Error:
//  InvalidParameterException: The target group with targetGroupArn
//  arn:aws:elasticloadbalancing:eu-west-1:428226611932:targetgroup/airflow/77a259290ea30e76
//  does not have an associated load balancer. "airflow"
resource "aws_ecs_service" "airflow" {
  depends_on = [aws_lb.airflow, aws_db_instance.airflow]

  name            = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  cluster         = aws_ecs_cluster.airflow.id
  task_definition = aws_ecs_task_definition.airflow.id
  desired_count   = 1
  enable_execute_command = true

  health_check_grace_period_seconds = 300

  network_configuration {
    subnets          = local.rds_ecs_subnet_ids
    security_groups  = [aws_security_group.airflow.id]
    assign_public_ip = length(var.private_subnet_ids) == 0 ? true : false
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 100
  }

  load_balancer {
    container_name   = local.airflow_webserver_container_name
    container_port   = 8080
    target_group_arn = aws_lb_target_group.airflow.arn
  }
}

resource "aws_lb_target_group" "airflow" {
  name        = "${var.resource_prefix}-airflow-${var.resource_suffix}"
  vpc_id      = var.vpc_id
  protocol    = "HTTP"
  port        = 8080
  target_type = "ip"

  health_check {
    port                = 8080
    protocol            = "HTTP"
    interval            = 30
    unhealthy_threshold = 5
    matcher             = "200-399"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}
