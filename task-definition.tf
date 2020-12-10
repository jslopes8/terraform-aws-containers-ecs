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
# ECS - Task Definition
#

resource "aws_ecs_task_definition" "main" {
    depends_on = [ aws_iam_role.main ]

    count = var.create && var.cluster_type == "FARGATE" || var.cluster_type == "EC2" ? length(var.task_definition) : 0

    family                      = lookup(var.task_definition[count.index], "family", null)
    #container_definitions       = data.template_file.container.0.rendered
    container_definitions       = lookup(var.task_definition[count.index], "container_definitions", var.container_definitions)
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
