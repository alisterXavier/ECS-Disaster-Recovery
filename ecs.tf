resource "aws_kms_key" "ecs_kms_key" {
  description             = "ecs_ kms_key"
  deletion_window_in_days = 7
}
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name = "ecs_log_group"
}
resource "aws_ecs_cluster" "CloudOpsBlend" {
  name = "CloudOpsBlend"
  configuration {

    execute_command_configuration {
      logging    = "OVERRIDE"
      kms_key_id = aws_kms_key.ecs_kms_key.arn
      log_configuration {
        s3_bucket_encryption_enabled   = true
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_log_group.name
      }
    }
  }
}
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "aws_iam_instance_profile"
  role = aws_iam_role.ec2_node_role.name
  path = "/ecs/instance/"
}

data "aws_ssm_parameter" "ecs_node_ami" { ## EC2 Needs to be an ecs-optimized instance
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}
resource "aws_launch_template" "ecs_launch_template" {
  name                   = "ecs_launch_template"
  image_id               = data.aws_ssm_parameter.ecs_node_ami.value
  instance_type          = "t3.medium"
  vpc_security_group_ids = [aws_security_group.ecs-nodes.id]
  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_instance_profile.arn
  }

  ## Required to register the ec2 node with the cluster
  user_data = base64encode(<<-EOF
      #!/bin/bash
      echo ECS_CLUSTER=${aws_ecs_cluster.CloudOpsBlend.name} >> /etc/ecs/ecs.config;
    EOF
  )
}
resource "aws_autoscaling_group" "ecs_autoscaling_group" {
  name                      = "ecs_autoscaling_group"
  vpc_zone_identifier       = aws_subnet.public_subnets[*].id
  min_size                  = 1
  desired_capacity          = 2
  max_size                  = 6
  health_check_grace_period = 0
  health_check_type         = "EC2"
  protect_from_scale_in     = false #
  launch_template {
    id      = aws_launch_template.ecs_launch_template.id
    version = "$Latest"
  }
  tag {
    key                 = "AmazonECSManaged" ## Important
    value               = ""
    propagate_at_launch = true
  }
  termination_policies = ["OldestInstance"]
}
resource "aws_ecs_capacity_provider" "cap_provider" {
  name = "cap-provider"
  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_autoscaling_group.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = var.region == "primary" ? "ENABLED" : "DISABLED"
      target_capacity           = 50
    }

    # managed_draining = "DISABLED"
  }
}
resource "aws_ecs_cluster_capacity_providers" "ecs_cap_provider" {
  cluster_name       = aws_ecs_cluster.CloudOpsBlend.name
  capacity_providers = [aws_ecs_capacity_provider.cap_provider.name]
  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.cap_provider.name
    base              = 1
    weight            = 100
  }
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  family             = "service"
  execution_role_arn = aws_iam_role.task_execution_role.arn
  task_role_arn      = aws_iam_role.task_execution_role.arn
  network_mode       = "awsvpc"
  cpu                = 1024
  memory             = 2048
  container_definitions = jsonencode([{
    name : aws_ecs_cluster.CloudOpsBlend.name,
    image : "docker.io/alisterxavier153/simple-node-server-80:latest",
    essential : true,
    logConfiguration : {
      logDriver : "awslogs",
      options : {
        awslogs-group : aws_cloudwatch_log_group.ecs_log_group.name,
        awslogs-region : "us-east-1",
        awslogs-stream-prefix : "ecs"
      }
    },
    portMappings : [{
      name : "server-80-tcp",
      containerPort : 80,
      hostPort : 80,
      protocol : "tcp",
      appProtocol : "http"
    }],
  }])
}
resource "aws_ecs_service" "ecs_service" {
  name            = "ECS_Service"
  cluster         = aws_ecs_cluster.CloudOpsBlend.id
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  launch_type     = "EC2"
  desired_count   = 1
  load_balancer {
    target_group_arn = aws_lb_target_group.lb_target_group.arn
    container_name   = aws_ecs_cluster.CloudOpsBlend.name
    container_port   = 80
  }
  # capacity_provider_strategy {
  #   capacity_provider = aws_ecs_capacity_provider.cap_provider.name
  #   weight            = 10
  # }
  force_new_deployment = true
  network_configuration {
    subnets         = aws_subnet.public_subnets[*].id
    security_groups = [aws_security_group.ecs-task.id]
  }
}
resource "aws_lb" "ecs_service_load_balancer" {
  name               = "ecs-service-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs-lb.id]
  subnets            = aws_subnet.public_subnets[*].id
}
resource "aws_lb_target_group" "lb_target_group" {
  name        = "lb-target-group"
  vpc_id      = aws_vpc.vpc.id
  protocol    = "HTTP"
  port        = 80
  target_type = "ip"
  health_check {
    path = "/"
  }
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_lb_listener" "ecs_lb_listener" {
  load_balancer_arn = aws_lb.ecs_service_load_balancer.arn
  protocol          = "HTTP"
  port              = 80
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group.arn
  }
}
