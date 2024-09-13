resource "aws_route53_record" "primary-failover" {
  zone_id        = local.zone_id
  name           = "${var.region}-test.${local.domain_name}"
  type           = "CNAME"
  ttl            = 300
  set_identifier = var.region
  records        = [aws_lb.ecs_service_load_balancer.dns_name]
  failover_routing_policy {
    type = upper(var.region)
  }

  health_check_id = aws_route53_health_check.primary_health_check.id
}
resource "aws_cloudwatch_metric_alarm" "primary_health_check_metric_alarm" {
  count = var.region == "secondary" ? 1 : 0

  alarm_name          = "primary_health_check_metric_alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1

  metric_name = "HealthCheckStatus"
  namespace   = "AWS/Route53"
  period      = 60
  statistic   = "Maximum"
  threshold   = 1
  dimensions = {
    HealthCheckId = "${aws_route53_health_check.primary_health_check.id}"
  }
  alarm_actions = [aws_lambda_function.scale[0].arn]

}
resource "aws_route53_health_check" "primary_health_check" {
  fqdn              = "primary-test.${local.domain_name}"
  port              = 80
  type              = "HTTP"
  resource_path     = "/check"
  failure_threshold = "5"
  request_interval  = "30"
  tags = {
    Name = "tf-test-health-check"
  }
}
