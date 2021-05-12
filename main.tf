#################################################################################################
#
# ECS - Cluster ECS
#

resource "aws_ecs_cluster" "main" {
    count = var.create ? 1 : 0

    name = var.cluster_name
    capacity_providers  = var.ecs_capacity_providers

    dynamic "default_capacity_provider_strategy" {
        for_each = var.default_capacity_provider
        content {
            capacity_provider   = default_capacity_provider_strategy.value.capacity_provider
            weight              = lookup(default_capacity_provider_strategy.value, "weight", null)
            base                = lookup(default_capacity_provider_strategy.value, "base", null)
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

    depends_on = [ aws_ecs_capacity_provider.ec2 ]
}
