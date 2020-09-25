resource "aws_iam_role" "main" {
    count = var.create && var.cluster_type == "FARGATE" ? length(var.task_definition) : 0

    name               = "ecs-${var.cluster_name}-role"
    assume_role_policy = data.aws_iam_policy_document.main.0.json
    path               = var.path
    description        = var.description

    tags               = var.default_tags
}
data "aws_iam_policy_document" "main" {
    count = var.create && var.cluster_type == "FARGATE" ? length(var.task_definition) : 0

    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type        = "Service"
            identifiers = ["ecs-tasks.amazonaws.com"]
        }
    }
}
data "aws_iam_policy" "main" {
    count = var.create && var.cluster_type == "FARGATE" ? length(var.task_definition) : 0

    arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_policy" "main" {
    count = var.create && var.cluster_type == "FARGATE" ? length(var.task_definition) : 0

    name        = "ecs-${var.cluster_name}-role-policy"
    policy      = data.aws_iam_policy.main.0.policy
    path        = var.path
    description = var.description
}
resource "aws_iam_role_policy_attachment" "main" {
    count = var.create && var.cluster_type == "FARGATE" ? length(var.task_definition) : 0

    role       = aws_iam_role.main.0.name
    policy_arn = aws_iam_policy.main.0.arn
}
resource "aws_ecs_cluster" "main" {
    count = var.create ? 1 : 0

    name = var.cluster_name
    capacity_providers  = var.capacity_providers

    dynamic "default_capacity_provider_strategy" {
        for_each = var.capacity_provider_strategy
        content {
            capacity_provider   = var.capacity_provider_strategy.value.capacity_provider
            weight              = lookup(var.capacity_provider_strategy.value, "weight", null)
            base                = lookup(var.capacity_provider_strategy.value, "base", null)
        }
    }

    dynamic "setting" {
        for_each = var.setting 
        content {
            name    = lookup(setting.value, "name", null)
            value   = lookup(setting.value, "value", null)
        }
    }

    tags = var.default_tags
}
data "template_file" "container" {
    count = var.create && var.cluster_type == "FARGATE" ? length(var.task_definition) : 0

    template = "${file("${path.module}/template.json")}"
    vars = {
        container_name  = lookup(var.task_definition[count.index], "container_name", null)
        image           = lookup(var.task_definition[count.index], "image", null)
        container_port  = lookup(var.task_definition[count.index], "container_port", null)
        host_port       = lookup(var.task_definition[count.index], "host_port", null)
        network_mode    = lookup(var.task_definition[count.index], "network_mode", null)
        container_cpu    = lookup(var.task_definition[count.index], "container_cpu", null)
        container_memory = lookup(var.task_definition[count.index], "container_memory", null)
        essential       = lookup(var.task_definition[count.index], "essential", null)
  }
}
#####################################
#   Cluster FARGATE                 #
#####################################

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
    depends_on = [ aws_iam_role.main ]

    count = var.create && var.cluster_type == "FARGATE" ? length(var.task_definition) : 0

    family                      = lookup(var.task_definition[count.index], "family", null)
    container_definitions       = data.template_file.container.0.rendered
    requires_compatibilities    = lookup(var.task_definition[count.index], "requires_compatibilities", null)

    cpu     = lookup(var.task_definition[count.index], "cpu", null)
    memory  = lookup(var.task_definition[count.index], "memory", null)

    task_role_arn       = aws_iam_role.main.0.arn
    execution_role_arn  = aws_iam_role.main.0.arn
    #execution_role_arn  = lookup(var.task_definition[count.index], "execution_role_arn", null)
    network_mode        = lookup(var.task_definition[count.index], "network_mode", null)

    tags = var.default_tags
}

#  ECS Service
resource "aws_ecs_service" "without_alb" {
    depends_on = [ aws_iam_role.main, aws_ecs_task_definition.main ]
    
    count = var.create && var.cluster_type == "FARGATE" && length(var.service_load_balancing) == 0 && length(var.service_load_balancing_https) == 0 ? length(var.service) : 0

    cluster         = aws_ecs_cluster.main.0.id
    task_definition = element(aws_ecs_task_definition.main.*.arn, count.index)

    name                = lookup(var.service[count.index], "name_service", null)
    launch_type         = lookup(var.service[count.index], "launch_type", null)
    desired_count       = lookup(var.service[count.index], "desired_count", null)
    platform_version    = lookup(var.service[count.index], "platform_version", null)
    scheduling_strategy = lookup(var.service[count.index], "scheduling_strategy", null)

    deployment_controller {
        type = lookup(var.service[count.index], "deployment_controller_type", null)
    }

    network_configuration {
        subnets             = lookup(var.service[count.index], "subnets", null)
        assign_public_ip    = lookup(var.service[count.index], "assign_public_ip", null)
        security_groups     = [ aws_security_group.main.0.id ]
    }

    lifecycle {
        ignore_changes = [ desired_count ]
    }
    #tags    = var.default_tags
}

resource "aws_ecs_service" "main" {
    depends_on = [ aws_ecs_task_definition.main, aws_lb_target_group.main, aws_lb.main ]
    
    count = var.create && var.cluster_type == "FARGATE" && length(var.service_load_balancing) == 1 ? length(var.service) : 0

    cluster         = aws_ecs_cluster.main.0.id
    task_definition = element(aws_ecs_task_definition.main.*.arn, count.index)

    name                = lookup(var.service[count.index], "name_service", null)
    launch_type         = lookup(var.service[count.index], "launch_type", null)
    desired_count       = lookup(var.service[count.index], "desired_count", null)
    platform_version    = lookup(var.service[count.index], "platform_version", null)
    scheduling_strategy = lookup(var.service[count.index], "scheduling_strategy", null)

    deployment_controller {
        type = lookup(var.service[count.index], "deployment_controller_type", null)
    }

    load_balancer {
        target_group_arn    = aws_lb_target_group.main.0.arn
        container_name      = lookup(var.service[count.index], "container_name", null)
        container_port      = lookup(var.service[count.index], "container_port", null)
    }

    network_configuration {
        subnets             = lookup(var.service[count.index], "subnets", null)
        assign_public_ip    = lookup(var.service[count.index], "assign_public_ip", null)
        security_groups     = [ aws_security_group.main.0.id ]
    }

    lifecycle {
        ignore_changes = [ desired_count ]
    }
    #tags    = var.default_tags
}

resource "aws_ecs_service" "https_listeners" {
    depends_on = [ aws_ecs_task_definition.main, aws_lb_target_group.https_listeners, aws_lb.https_listeners ]
    
    count = var.create && var.cluster_type == "FARGATE" && length(var.service_load_balancing_https) == 1 ? length(var.service) : 0

    cluster         = aws_ecs_cluster.main.0.id
    task_definition = element(aws_ecs_task_definition.main.*.arn, count.index)

    name                = lookup(var.service[count.index], "name_service", null)
    launch_type         = lookup(var.service[count.index], "launch_type", null)
    desired_count       = lookup(var.service[count.index], "desired_count", null)
    platform_version    = lookup(var.service[count.index], "platform_version", null)
    scheduling_strategy = lookup(var.service[count.index], "scheduling_strategy", null)

    deployment_controller {
        type = lookup(var.service[count.index], "deployment_controller_type", null)
    }

    load_balancer {
        target_group_arn    = aws_lb_target_group.https_listeners.0.arn
        container_name      = lookup(var.service[count.index], "container_name", null)
        container_port      = lookup(var.service[count.index], "container_port", null)
    }

    network_configuration {
        subnets             = lookup(var.service[count.index], "subnets", null)
        assign_public_ip    = lookup(var.service[count.index], "assign_public_ip", null)
        security_groups     = [ aws_security_group.main.0.id ]
    }

    lifecycle {
        ignore_changes = [ desired_count ]
    }
    #tags    = var.default_tags
}

resource "aws_security_group" "main" {
    count = var.create && var.cluster_type == "FARGATE" ? length(var.service) : 0

    name    = lookup(var.service[count.index], "name_service", null)
    vpc_id  = lookup(var.service[count.index], "vpc_id", null)
    tags    = var.default_tags
}
resource "aws_security_group_rule" "ingress" {
    count = var.create && var.cluster_type == "FARGATE" ? length(var.service) : 0

  type              = "ingress"
  from_port         = lookup(var.service[count.index], "security_group_container_port", null)
  to_port           = lookup(var.service[count.index], "security_group_container_port", null)
  protocol          = "tcp"
  cidr_blocks       = [ "0.0.0.0/0" ]
  security_group_id = aws_security_group.main.0.id
}
resource "aws_security_group_rule" "egress" {
    count = var.create && var.cluster_type == "FARGATE" ? length(var.service) : 0

    type              = "egress"
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = [ "0.0.0.0/0" ]
    security_group_id = aws_security_group.main.0.id
}

# Service Auto Scaling
resource "aws_appautoscaling_target" "main" {
    count = var.create && var.cluster_type == "FARGATE" && length(var.service_load_balancing) == 1 ? length(var.service_auto_scaling) : 0

    max_capacity       = lookup(var.service_auto_scaling[count.index], "max_capacity", null)
    min_capacity       = lookup(var.service_auto_scaling[count.index], "min_capacity", null)
    resource_id        = "service/${var.cluster_name}/${aws_ecs_service.main.0.name}"
    scalable_dimension = "ecs:service:DesiredCount"
    service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy" {
    count = var.create && var.cluster_type == "FARGATE" && length(var.service_load_balancing) == 1 ? length(var.service_auto_scaling) : 0

    name               = "${aws_ecs_service.main.0.name}-CPUAutoScaling"
    policy_type        = lookup(var.service_auto_scaling[count.index], "policy_type", null)
    resource_id        = aws_appautoscaling_target.main.0.resource_id
    scalable_dimension = aws_appautoscaling_target.main.0.scalable_dimension
    service_namespace  = aws_appautoscaling_target.main.0.service_namespace

    target_tracking_scaling_policy_configuration {
        predefined_metric_specification {
            predefined_metric_type = lookup(var.service_auto_scaling[count.index], "metric_type", null) 
        }

        target_value       = lookup(var.service_auto_scaling[count.index], "target_value", null)
        scale_in_cooldown  = lookup(var.service_auto_scaling[count.index], "scale_in_cooldown", "300")
        scale_out_cooldown = lookup(var.service_auto_scaling[count.index], "scale_out_cooldown", "300")
    }
}

resource "aws_lb" "main" {
    count = var.create && var.cluster_type == "FARGATE" ? length(var.service_load_balancing) : 0

    name               = lookup(var.service_load_balancing[count.index], "name", null) 
    internal           = lookup(var.service_load_balancing[count.index], "internal", null)
    load_balancer_type = lookup(var.service_load_balancing[count.index], "load_balancer_type", "application")
    security_groups    = [ aws_security_group.main.0.id ]
    subnets            = lookup(var.service_load_balancing[count.index], "subnets", null)
}
resource "aws_lb_listener" "main" {
    count = var.create && var.cluster_type == "FARGATE" ? length(var.service_load_balancing) : 0

    load_balancer_arn = aws_lb.main.0.arn
    port              = lookup(var.service_load_balancing[count.index], "port", null)
    protocol          = lookup(var.service_load_balancing[count.index], "protocol", null)

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.main.0.arn
    }
}
resource "aws_lb_target_group" "main" {
    count = var.create && var.cluster_type == "FARGATE" ? length(var.service_load_balancing) : 0

    name            = lookup(var.service_load_balancing[count.index], "name", null)
    port            = lookup(var.service_load_balancing[count.index], "port", null)
    protocol        = lookup(var.service_load_balancing[count.index], "protocol", null)
    target_type     = lookup(var.service_load_balancing[count.index], "target_type", null)
    vpc_id          = lookup(var.service_load_balancing[count.index], "vpc_id", null)
}

## Support HTTPS

resource "aws_appautoscaling_target" "https_listeners" {
    count = var.create && var.cluster_type == "FARGATE" && length(var.service_load_balancing_https) == 1 ? length(var.service_auto_scaling) : 0

    max_capacity       = lookup(var.service_auto_scaling[count.index], "max_capacity", null)
    min_capacity       = lookup(var.service_auto_scaling[count.index], "min_capacity", null)
    resource_id        = "service/${var.cluster_name}/${aws_ecs_service.https_listeners.0.name}"
    scalable_dimension = "ecs:service:DesiredCount"
    service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "https_listeners" {
    count = var.create && var.cluster_type == "FARGATE" && length(var.service_load_balancing_https) == 1 ? length(var.service_auto_scaling) : 0

    name               = "${aws_ecs_service.https_listeners.0.name}-CPUAutoScaling"
    policy_type        = lookup(var.service_auto_scaling[count.index], "policy_type", null)
    resource_id        = aws_appautoscaling_target.https_listeners.0.resource_id
    scalable_dimension = aws_appautoscaling_target.https_listeners.0.scalable_dimension
    service_namespace  = aws_appautoscaling_target.https_listeners.0.service_namespace

    target_tracking_scaling_policy_configuration {
        predefined_metric_specification {
            predefined_metric_type = lookup(var.service_auto_scaling[count.index], "metric_type", null) 
        }

        target_value       = lookup(var.service_auto_scaling[count.index], "target_value", null)
        scale_in_cooldown  = lookup(var.service_auto_scaling[count.index], "scale_in_cooldown", "300")
        scale_out_cooldown = lookup(var.service_auto_scaling[count.index], "scale_out_cooldown", "300")
    }
}

resource "aws_lb" "https_listeners" {
    count = var.create && var.cluster_type == "FARGATE" ? length(var.service_load_balancing_https) : 0

    name               = lookup(var.service_load_balancing_https[count.index], "name", null) 
    internal           = lookup(var.service_load_balancing_https[count.index], "internal", null)
    load_balancer_type = lookup(var.service_load_balancing_https[count.index], "load_balancer_type", "application")
    security_groups    = [ aws_security_group.main.0.id ]
    subnets            = lookup(var.service_load_balancing_https[count.index], "subnets", null)
}
resource "aws_alb_listener" "https_listeners" {
    count = var.create ? length(var.service_load_balancing_https) : 0

    load_balancer_arn = aws_lb.https_listeners.0.arn

    port            = lookup(var.service_load_balancing_https[count.index], "port", null)
    protocol        = lookup(var.service_load_balancing_https[count.index], "protocol", null)
    certificate_arn = var.service_load_balancing_https[count.index]["certificate_arn"]
    ssl_policy      = lookup(var.service_load_balancing_https[count.index], "ssl_policy", "ELBSecurityPolicy-2016-08")

    default_action {
        target_group_arn = aws_lb_target_group.https_listeners.0.arn
        type             = "forward"
    }
}
resource "aws_lb_target_group" "https_listeners" {
    count = var.create && var.cluster_type == "FARGATE" ? length(var.service_load_balancing_https) : 0

    name            = lookup(var.service_load_balancing_https[count.index], "name", null)
    port            = lookup(var.service_load_balancing_https[count.index], "port", null)
    protocol        = lookup(var.service_load_balancing_https[count.index], "protocol", null)
    target_type     = lookup(var.service_load_balancing_https[count.index], "target_type", null)
    vpc_id          = lookup(var.service_load_balancing_https[count.index], "vpc_id", null)
}