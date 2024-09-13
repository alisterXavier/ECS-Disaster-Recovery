resource "aws_security_group" "ecs-nodes" {
  name   = "ecs-nodes"
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "ecs-lb" {
  name   = "ecs-lb"
  vpc_id = aws_vpc.vpc.id
  dynamic "ingress" {
    for_each = [80, 443]
    content {
      protocol    = "tcp"
      from_port   = ingress.value
      to_port     = ingress.value
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "ecs-task" {
  name   = "ecs-task"
  vpc_id = aws_vpc.vpc.id
}
resource "aws_security_group_rule" "allow_all_traffic_from_lb" {
  security_group_id        = aws_security_group.ecs-task.id
  protocol                 = "tcp"
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  source_security_group_id = aws_security_group.ecs-lb.id
}
