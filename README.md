# Terraform AWS Cluster ECS



## Usage
Exemplo de uso: Criando um completo Cluster ECS Fargate
```hcl
module "cluster_ecs" {
    source = "git@github.com:jslopes8/terraform-aws-containers-ecs.git?ref=v2.3.3"

    cluster_name = local.cluster_name
    cluster_type = "FARGATE"

    task_definition = [
        {
            family                      = "demo-php"
            requires_compatibilities    = [ "FARGATE", "EC2" ]
            network_mode                = "awsvpc"
            cpu                         = "256"
            memory                      = "512"

            container_definitions   = <<EOF
            [
                {
                    "name": "demo-php",
                    "image": "nginx:latest",
                    "networkMode": "awsvpc",
                    "cpu": 10,
                    "memory": 256,
                    "essential": true,
                    "portMappings": [
                        {
                            "containerPort": 80,
                            "protocol": "tcp"
                        }
                    ],
                    "environment": [
                        {
                            "name": "Env",
                            "value": "Lab"
                        }
                    ],
                    "logConfiguration": {
                        "logDriver": "awslogs",
                        "options": {
                            "awslogs-group": "/ecs/svc-demo-php",
                            "awslogs-region": "us-east-1",
                            "awslogs-stream-prefix": "ecs"
                        }
                    }
                }
            ]
            EOF
        }
    ]

    log_driver = [
        {
            log_name            = "/ecs/svc-php-demo"
            retention_in_days   = "3"
            default_tags        = local.default_tags
        }
    ]

    service = [{
        name_service            = "svc-demo-php"
        launch_type             = "FARGATE"
        desired_count           = "1"
        platform_version        = "1.4"
        scheduling_strategy     = "REPLICA"

        network_configuration   = {
            subnets = [
                tolist(data.aws_subnet_ids.subnet_priv.ids)[0],
                tolist(data.aws_subnet_ids.subnet_priv.ids)[1]
            ]
            security_groups     = [
                module.ecs_sec_group.id
            ]
        }

        load_balancer = {
            container_name      = "demo-php"
            container_port      = "80"
        }

    }]

    service_auto_scaling = [{
        policy_type         = "TargetTrackingScaling"

        min_capacity    = "1"
        max_capacity    = "2"

        target_scaling_policy = {
            target_value        = "75"
            scale_in_cooldown   = "300"
            scale_out_cooldown  = "300"

            metric_specification = {
                metric_type = "ECSServiceAverageCPUUtilization"
            }
        }
    }]

    default_tags = local.default_tags
}
``` 

Exemplo de uso: Criando um Cluster EC2 com EC2 Instance
```hcl
module "ecs" {
    source = "git::https://github.com/jslopes8/terraform-aws-containers-ecs.git?ref=v3.3.3"

    cluster_name = local.cluster_name
    cluster_type = "EC2"

    cluster_resources   = [{
        image_id        = "ami-0128839b21d19300e"
        instance_type   = "m5zn.large"

        desired_capacity    = "2"
        min_size            = "2"
        max_size            = "8"
        health_check_type           = "EC2"
        health_check_grace_period   = "300"


        vpc_zone_identifier = [
            tolist(data.aws_subnet_ids.subnet_priv.ids)[0],
            tolist(data.aws_subnet_ids.subnet_priv.ids)[1]
        ]
        security_groups = [  module.ecs_sec_group.id  ]

        key_name        = "sshkey-name"
        user_data       = data.template_file.user_data.rendered

        volume_type             = "gp2"
        volume_size             = "80"
        delete_on_termination   = "true"
    }]

 - - - omitindo saída - - -
}
```

Exemplo de uso: Criando um Cluster EC2 com Capacity Providers
```hcl
module "ecs" {
    source = "git::https://github.com/jslopes8/terraform-aws-containers-ecs.git?ref=v3.0"

    cluster_name = local.cluster_name
    cluster_type = "EC2"

    ecs_capacity_providers = ["CAS-NameCapacityProviders"]
    capacity_provider = [{
      name_capacity_provider = "CAS-NameCapacityProviders"

      auto_scaling_group_provider = [{
        managed_termination_protection = "ENABLED"

        managed_scaling = [{
          maximum_scaling_step_size = "100000"
          minimum_scaling_step_size = "10"
          status                    = "ENABLED"
          target_capacity           = "100"
          instance_warmup_period    = "300"
        }]
      }]
    }]

 - - - omitindo saída - - -
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Variables Inputs
| Name | Description | Required | Type | Default |
| ---- | ----------- | --------- | ---- | ------- |
| cluster_name | O nome do cluster. | `yes` | `string` | ` ` |
| cluster_type | O tipo que será inicializado o cluster. Valores validos, FARGATE e EC2. | `yes` | `string` | ` ` |
| task_definition | O bloco task_definition é necessario para rodar containers Dockers em ECS. Segue detalhes abaixo. | `yes` | `list` | `[ ]` |
| capacity_providers | Lista de um ou mais provedores de capacidade para associar ao cluster. Valores validos, FARGATE e FARGATE_SPOT. | `no` | `list` | `[ ]` |
| default_capacity_provider_strategy | Capacity Provider Strategy para ser usado por default para o cluster. Segue detalhes abaixo.  | `no` | `list` | `[ ]` |
| cluster_resources | Construção da EC2 Instance para o EC2 Cluster. Obrigatorio quando o valor de `cluster_type` for EC2. | `no` | `list` | `[ ]` |

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Variables Inputs
| Name | Description | 
| ---- | ----------- |
| lb_dns | DNS name do Load Balance. |
| cluster_name | O nome do cluster ECS criado. |
