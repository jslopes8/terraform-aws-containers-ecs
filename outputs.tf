output "dns" {
    value   = length(aws_lb.main) > 0 ? aws_lb.main.0.dns_name : aws_lb.lb_https.0.dns_name
}
