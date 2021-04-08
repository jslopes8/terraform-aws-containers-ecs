output "lb_dns" {
    value   = length(aws_lb.main) > 0 ? aws_lb.main.0.dns_name : aws_lb.lb_https.0.dns_name
}
output "cluster_name" {
  value = aws_ecs_cluster.main.0.name
}

