#################################################################################################
#
# ECS - Services
#

# ECS Service - Create a ECS services wihtout load balance

resource "time_sleep" "wait_for_ec2_instances" {
    count = var.create && var.cluster_type == "EC2" ? length(var.service) : 0

    depends_on = [ aws_launch_configuration.ec2, aws_autoscaling_group.ec2  ]

    create_duration = "30s"
}

resource "aws_ecs_service" "main" {
    depends_on = [ 
        aws_iam_role.main, aws_ecs_task_definition.main, 
        aws_lb.main, aws_lb_target_group.main
    ]

    count = var.create && var.cluster_type == "FARGATE" || var.cluster_type == "EC2" ? length(var.service) : 0

    cluster         = aws_ecs_cluster.main.0.id
    task_definition = element(aws_ecs_task_definition.main.*.arn, count.index)

    name                    = lookup(var.service[count.index], "name_service", null)
    enable_ecs_managed_tags = lookup(var.service[count.index], "managed_tags", null)
    launch_type             = lookup(var.service[count.index], "launch_type", null)
    desired_count           = lookup(var.service[count.index], "desired_count", null)
    platform_version        = lookup(var.service[count.index], "platform_version", null)
    scheduling_strategy     = lookup(var.service[count.index], "scheduling_strategy", null)

    deployment_minimum_healthy_percent  = lookup(var.service[count.index], "minimum_healthy_percent", "100")
    deployment_maximum_percent          = lookup(var.service[count.index], "maximum_healthy_percent", "200")

    dynamic "deployment_controller" {
        for_each = lookup(var.service[count.index], "deployment_controller", var.deployment_controller)
        content {
            type    = lookup(deployment_controller.value, "type", null)
        }
    }

    dynamic "ordered_placement_strategy" {
        for_each = lookup(var.service[count.index], "placement_strategy", var.placement_strategy)
        content {
            type    = lookup(ordered_placement_strategy.value, "type", null)
            field   = lookup(ordered_placement_strategy.value, "field", null)
        }
    }

    dynamic "placement_constraints" {
        for_each = lookup(var.service[count.index], "placement_constraints", var.placement_constraints)
        content {
            type        = lookup(placement_constraints.value, "type", null)
            expression  = lookup(placement_constraints.value, "expression", null)
        }
    }

    dynamic "network_configuration" {
        for_each = length(keys(lookup(var.service[count.index], "network_configuration", {}))) == 0 ? [] : [lookup(var.service[count.index], "network_configuration", {})]
        content {
            subnets             = lookup(network_configuration.value, "subnets", null)
            assign_public_ip    = lookup(network_configuration.value, "assign_public_ip", "false")
            security_groups     = lookup(network_configuration.value, "security_groups", null)
        }
    }

    dynamic "load_balancer" {
        for_each = length(keys(lookup(var.service[count.index], "load_balancer", {}))) == 0 ? [] : [lookup(var.service[count.index], "load_balancer", {})]
        content {
            target_group_arn    = aws_lb_target_group.main.0.arn
            container_name      = lookup(load_balancer.value, "container_name", null)
            container_port      = lookup(load_balancer.value, "container_port", null)
        }
    }

    lifecycle {
        ignore_changes = [ desired_count ]
    }
}

#
# ECS Service - Service Auto Scaling
#

resource "aws_appautoscaling_target" "main" {
    count = var.create && var.cluster_type == "FARGATE" || var.cluster_type == "EC2" ? length(var.service_auto_scaling) : 0

    max_capacity       = lookup(var.service_auto_scaling[count.index], "max_capacity", null)
    min_capacity       = lookup(var.service_auto_scaling[count.index], "min_capacity", null)
    resource_id        = "service/${var.cluster_name}/${aws_ecs_service.main.0.name}"
    scalable_dimension = "ecs:service:DesiredCount"
    service_namespace  = "ecs"

    depends_on = [ aws_ecs_service.main ]
}
resource "aws_appautoscaling_policy" "ecs_policy" {
    count = var.create && var.cluster_type == "FARGATE" || var.cluster_type == "EC2" ? length(var.service_auto_scaling) : 0

    name               = "${aws_ecs_service.main.0.name}-CPUAutoScaling"
    policy_type        = lookup(var.service_auto_scaling[count.index], "policy_type", null)
    resource_id        = aws_appautoscaling_target.main.0.resource_id
    scalable_dimension = aws_appautoscaling_target.main.0.scalable_dimension
    service_namespace  = aws_appautoscaling_target.main.0.service_namespace

    dynamic "target_tracking_scaling_policy_configuration" {
        for_each = length(keys(lookup(var.service_auto_scaling[count.index], "target_scaling_policy", {}))) == 0 ? [] : [lookup(var.service_auto_scaling[count.index], "target_scaling_policy", {})]
        content {
            target_value       = lookup(target_tracking_scaling_policy_configuration.value, "target_value", null)
            scale_in_cooldown  = lookup(target_tracking_scaling_policy_configuration.value, "scale_in_cooldown", "300")
            scale_out_cooldown = lookup(target_tracking_scaling_policy_configuration.value, "scale_out_cooldown", "300")

            dynamic "predefined_metric_specification" {
                for_each = length(keys(lookup(target_tracking_scaling_policy_configuration.value, "metric_specification", {}))) == 0 ? [] : [lookup(target_tracking_scaling_policy_configuration.value, "metric_specification", {})]
                content {
                    predefined_metric_type =  lookup(predefined_metric_specification.value, "metric_type", null)
                }
            }
        }
    }
    depends_on = [ aws_ecs_service.main ]
}

#
# ECS Service - Service Application Load Balance
#

resource "aws_lb" "main" {
    count = var.create && var.cluster_type == "FARGATE" || var.cluster_type == "EC2" ? length(var.service_load_balancing) : 0

    name               = lookup(var.service_load_balancing[count.index], "name", null)
    internal           = lookup(var.service_load_balancing[count.index], "internal", "false")
    load_balancer_type = lookup(var.service_load_balancing[count.index], "load_balancer_type", "application")
    security_groups    = lookup(var.service_load_balancing[count.index], "security_groups", null)
    subnets            = lookup(var.service_load_balancing[count.index], "subnets", null)

    tags = var.default_tags

    depends_on = [ aws_lb_target_group.main  ]
}


resource "aws_lb_listener" "listerner" {
    count = var.create && var.cluster_type == "FARGATE" || var.cluster_type == "EC2" ? length(var.service_load_balancing) : 0

    load_balancer_arn   = aws_lb.main.0.arn
    port                = lookup(var.service_load_balancing[count.index], "port", null)
    protocol            = lookup(var.service_load_balancing[count.index], "protocol", null)
    certificate_arn     = lookup(var.service_load_balancing[count.index], "certificate_arn", null)
    ssl_policy          = lookup(var.service_load_balancing[count.index], "ssl_policy", null)

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.main.0.arn
    }

    depends_on = [ time_sleep.wait_for_ec2_instances, aws_lb_target_group.main     ]
}

resource "aws_lb_listener_rule" "listener_rule" {
    count = var.create  && var.priority != "null" && var.cluster_type == "FARGATE" || var.cluster_type == "EC2" &&  var.priority != "null" ? length(var.service_load_balancing) : 0

    listener_arn    = aws_lb_listener.listerner.0.arn
    priority        = lookup(var.service_load_balancing[count.index], "priority", var.priority)

    dynamic "action" {
        for_each = length(keys(lookup(var.service_load_balancing[count.index], "redirect_rule", {}))) == 0 ? [] : [lookup(var.service_load_balancing[count.index], "redirect_rule", {})]
        content {
            type    = lookup(action.value, "type", null)

            dynamic "redirect" {
                for_each = length(keys(lookup(action.value, "redirect", {}))) == 0 ? [] : [lookup(action.value, "redirect", {})]
                content {
                    port        = lookup(redirect.value, "type", "443")
                    protocol    = lookup(redirect.value, "protocol", "HTTPS")
                    status_code = lookup(redirect.value, "status_code", "HTTP_301")
                }
            }

        }
    }

    dynamic "action" {
        for_each = length(keys(lookup(var.service_load_balancing[count.index], "forward_rule", {}))) == 0 ? [] : [lookup(var.service_load_balancing[count.index], "forward_rule", {})]
        content {
            type                = lookup(action.value, "type", null)
            target_group_arn    = aws_lb_target_group.main.0.arn

        }
    }

    dynamic "condition" {
        for_each = length(keys(lookup(var.service_load_balancing[count.index], "condition", {}))) == 0 ? [] : [lookup(var.service_load_balancing[count.index], "condition", {})]
        content {
            dynamic "path_pattern" {
                for_each = length(keys(lookup(condition.value, "path_pattern", {}))) == 0 ? [] : [lookup(condition.value, "path_pattern", {})]
                content {
                    values = lookup(path_pattern.value, "values", null)
                }
            }
        }
    }

    depends_on = [ aws_lb_target_group.main, aws_lb.main ]
}

resource "aws_lb_target_group" "main" {
    count = var.create && var.cluster_type == "FARGATE" || var.cluster_type == "EC2" ? length(var.service_load_balancing) : 0

    name            = lookup(var.service_load_balancing[count.index], "name", null)
    port            = lookup(var.service_load_balancing[count.index], "target_port", null)
    protocol        = lookup(var.service_load_balancing[count.index], "target_protocol", null)
    target_type     = lookup(var.service_load_balancing[count.index], "target_type", null)
    vpc_id          = lookup(var.service_load_balancing[count.index], "vpc_id", null)


    dynamic "health_check" {
        for_each = length(keys(lookup(var.service_load_balancing[count.index], "health_check", {}))) == 0 ? [] : [lookup(var.service_load_balancing[count.index], "health_check", {})]
        content {
            healthy_threshold   = lookup(health_check.value, "healthy_threshold", null)
            unhealthy_threshold = lookup(health_check.value, "unhealthy_threshold", null)
            timeout             = lookup(health_check.value, "timeout", null)
            interval            = lookup(health_check.value, "interval", null)
            path                = lookup(health_check.value, "path", null)
            port                = lookup(health_check.value, "health_check_port", "traffic-port")
            matcher             = lookup(health_check.value, "success_codes", null)
        }
    }

    tags = var.default_tags
}
