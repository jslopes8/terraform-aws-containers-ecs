#################################################################################################
#
# ECS - Task Definition
#

# IAM Role - Create a role for task-definition

resource "aws_iam_role" "main" {
    count = var.create && var.cluster_type == "FARGATE" || var.cluster_type == "EC2" ? length(var.task_definition) : 0

    name               = "${var.cluster_name}TaskRole"
    assume_role_policy = data.aws_iam_policy_document.main.0.json
    path               = var.path
    description        = var.description

    tags               = var.default_tags
}

# IAM Policy - Create a policy assume-role

data "aws_iam_policy_document" "main" {
    count = var.create && var.cluster_type == "FARGATE" || var.cluster_type == "EC2" ? length(var.task_definition) : 0

    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type        = "Service"
            identifiers = ["ecs-tasks.amazonaws.com"]
        }
    }
}

data "aws_iam_policy" "main" {
    count = var.create && var.cluster_type == "FARGATE" || var.cluster_type == "EC2" ? length(var.task_definition) : 0

    arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "main" {
    count = var.create && var.cluster_type == "FARGATE" || var.cluster_type == "EC2" ? length(var.task_definition) : 0

    name        = "${var.cluster_name}TaskPolicy"
    policy      = data.aws_iam_policy.main.0.policy
    path        = var.path
    description = var.description
}

resource "aws_iam_role_policy_attachment" "main" {
    count = var.create && var.cluster_type == "FARGATE" || var.cluster_type == "EC2" ? length(var.task_definition) : 0

    role       = aws_iam_role.main.0.name
    policy_arn = aws_iam_policy.main.0.arn
}

#
# Task Definition - Template json
#

data "template_file" "container" {
    count = var.create && var.cluster_type == "FARGATE" || var.cluster_type == "EC2" ? length(var.task_definition) : 0

    template = file("${path.module}/template/container-definition.json")
    vars = {
        container_name      = lookup(var.task_definition[count.index], "container_name", null)
        image               = lookup(var.task_definition[count.index], "image", null)
        container_port      = lookup(var.task_definition[count.index], "container_port", null)
        host_port           = lookup(var.task_definition[count.index], "host_port", null)
        network_mode        = lookup(var.task_definition[count.index], "network_mode", null)
        container_cpu       = lookup(var.task_definition[count.index], "container_cpu", null)
        container_memory    = lookup(var.task_definition[count.index], "container_memory", null)
        essential           = lookup(var.task_definition[count.index], "essential", null)

        #LogDriver
        log_driver  = lookup(var.task_definition[count.index], "log_driver", null)
        awslogs_group  = lookup(var.task_definition[count.index], "awslogs_group", null)
        awslogs_region  = lookup(var.task_definition[count.index], "awslogs_region", null)
        awslogs_stream_prefix  = lookup(var.task_definition[count.index], "awslogs_stream_prefix", null)
  }
}

#
# ECS - Task Definition
#

resource "aws_ecs_task_definition" "main" {
    depends_on = [ aws_iam_role.main ]

    count = var.create && var.cluster_type == "FARGATE" || var.cluster_type == "EC2" ? length(var.task_definition) : 0

    family                      = lookup(var.task_definition[count.index], "family", null)
    container_definitions       = data.template_file.container.0.rendered
    requires_compatibilities    = lookup(var.task_definition[count.index], "requires_compatibilities", null)

    cpu     = lookup(var.task_definition[count.index], "cpu", null)
    memory  = lookup(var.task_definition[count.index], "memory", null)

    task_role_arn       = aws_iam_role.main.0.arn
    execution_role_arn  = aws_iam_role.main.0.arn
    network_mode        = lookup(var.task_definition[count.index], "network_mode", null)

    tags = var.default_tags
}

# Log Group for Task definition

resource "aws_cloudwatch_log_group" "main" {
    count = var.create && var.cluster_type == "FARGATE" || var.cluster_type == "EC2" ? length(var.log_driver) : 0

    name                = lookup(var.log_driver[count.index], "log_name", null)
    retention_in_days   = lookup(var.log_driver[count.index], "retention_in_days", null)

    tags = lookup(var.log_driver[count.index], "default_tags", var.default_tags)
}
