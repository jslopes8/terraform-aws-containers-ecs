resource "aws_iam_role" "ec2" {
    count = var.create && var.cluster_type == "EC2" ? 1 : 0

    name               = "${var.cluster_name}-Role"
    assume_role_policy = data.aws_iam_policy_document.ec2.0.json
    path               = var.path
    description        = var.description

    tags               = var.default_tags
}
data "aws_iam_policy_document" "ec2" {
    count = var.create && var.cluster_type == "EC2" ? 1 : 0

    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type        = "Service"
            identifiers = ["ec2.amazonaws.com"]
        }
    }
}
resource "aws_iam_role_policy_attachment" "ec2_0" {
    count = var.create && var.cluster_type == "EC2" ? 1 : 0

    role       = aws_iam_role.ec2.0.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}
resource "aws_iam_role_policy_attachment" "ec2_1" {
    count = var.create && var.cluster_type == "EC2" ? 1 : 0

    role       = aws_iam_role.ec2.0.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}

resource "aws_iam_instance_profile" "ec2" {
    count = var.create && var.cluster_type == "EC2" ? 1 : 0

    name = "${var.cluster_name}-Role"
    role = aws_iam_role.ec2.0.name
}

#
# Lanch Config
#

data "template_file" "bootstrap" {
    count = var.create && var.cluster_type == "EC2" ? length(var.cluster_resources) : 0

    template = file("${path.module}/template/bootstrap")
    vars = {
        cluster_name = var.cluster_name
    }
}


resource "aws_launch_configuration" "ec2" {
    count = var.create && var.cluster_type == "EC2" ? length(var.cluster_resources) : 0

    name_prefix                 = "LC-${upper(var.cluster_name)}-ECS-WORKER-"
    image_id                    = var.cluster_resources[count.index]["image_id"]
    instance_type               = var.cluster_resources[count.index]["instance_type"]
    iam_instance_profile        = aws_iam_instance_profile.ec2.0.name
    security_groups             = var.cluster_resources[count.index]["security_groups"]
    associate_public_ip_address = lookup(var.cluster_resources[count.index], "associate_public_ip_address", null)
    enable_monitoring           = lookup(var.cluster_resources[count.index], "enable_monitoring", null)
    ebs_optimized               = lookup(var.cluster_resources[count.index], "ebs_optimized", null)
    key_name                    = var.cluster_resources[count.index]["key_name"]
    user_data                   = data.template_file.bootstrap.0.rendered
    spot_price                  = lookup(var.cluster_resources[count.index], "spot_price", null)

    dynamic "root_block_device" {
        for_each = length(keys(lookup(var.cluster_resources[count.index], "root_block_device", {}))) == 0 ? [] : [lookup(var.cluster_resources[count.index], "root_block_device", {})]
        content {
            volume_type             = lookup(root_block_device.value, "volume_type", null)
            volume_size             = lookup(root_block_device.value, "volume_size", null)
            delete_on_termination   = lookup(root_block_device.value, "delete_on_termination", null)
            encrypted               = lookup(root_block_device.value, "encrypted", null)
        }
    }

    # it's recommended to specify create_before_destroy in a lifecycle block
    lifecycle {
        create_before_destroy = "true"
    }
    
    depends_on = [ aws_iam_role.ec2 ]
}

#
# ASG
#

resource "aws_autoscaling_group" "ec2" {
    count = var.create && var.cluster_type == "EC2" ? length(var.cluster_resources) : 0

    name                        = "${upper(var.cluster_name)}-AS"
    vpc_zone_identifier         = lookup(var.cluster_resources[count.index], "vpc_zone_identifier", null)
    launch_configuration        = aws_launch_configuration.ec2.0.name
    min_size                    = lookup(var.cluster_resources[count.index], "min_size", "1")
    max_size                    = lookup(var.cluster_resources[count.index], "max_size", "1")
    desired_capacity            = lookup(var.cluster_resources[count.index], "desired_capacity", "1")
    health_check_type           = lookup(var.cluster_resources[count.index], "health_check_type", null)
    health_check_grace_period   = lookup(var.cluster_resources[count.index], "health_check_grace_period", "300")
    default_cooldown            = lookup(var.cluster_resources[count.index], "default_cooldown", "300")
    protect_from_scale_in       = lookup(var.cluster_resources[count.index], "scale_in_protection", )

    tags    = concat([
         {
            "key"                   = "Name"
            "value"                 = "${var.cluster_name}-worker-as"
            "propagate_at_launch"   = true
         },
         {
            "key"                   = "AmazonECSManaged"
            "value"                 = ""
            "propagate_at_launch"   = true
          }
        ]
    )

    lifecycle {
        create_before_destroy = true
    }
    
    depends_on = [ aws_launch_configuration.ec2 ]
}

resource "aws_ecs_capacity_provider" "ec2" {
  count = var.create && var.cluster_type == "EC2" ? length(var.capacity_provider) : 0

  name  = lookup(var.capacity_provider[count.index], "name_capacity_provider", null)
  
  dynamic "auto_scaling_group_provider" {
    for_each = lookup(var.capacity_provider[count.index], "auto_scaling_group_provider", null)
    content {
      auto_scaling_group_arn          = aws_autoscaling_group.ec2.0.arn
      managed_termination_protection  = lookup(auto_scaling_group_provider.value, "managed_termination_protection", null)

      dynamic "managed_scaling" {
        for_each = lookup(auto_scaling_group_provider.value, "managed_scaling", null)
        content {
          maximum_scaling_step_size = lookup(managed_scaling.value, "maximum_scaling_step_size", null)
          minimum_scaling_step_size = lookup(managed_scaling.value, "minimum_scaling_step_size", null)
          status                    = lookup(managed_scaling.value, "status", null)
          target_capacity           = lookup(managed_scaling.value, "target_capacity", null)
          instance_warmup_period    = lookup(managed_scaling.value, "instance_warmup_period", null)
        }
      }
    }
  }

  depends_on = [ aws_autoscaling_group.ec2 ]
}
