# Terraform AWS Cluster ECS

Atualmente este module tem suporte para iniciar cluster em Fargate.

## Usage
Exemplo de uso do modulo.
```hcl
module "cluster_ecs" {
    source = "git@github.com:jslopes8/terraform-aws-containers-ecs.git?ref=v2.3.2"

    cluster_name = "cluster-demo-php"
    cluster_type = "FARGATE"

    task_definition = [
        {
            family                      = "demo-php"
            requires_compatibilities    = [ "FARGATE", "EC2" ]
            network_mode                = "awsvpc"
            cpu                         = "256"
            memory                      = "512"

            #add container
            container_name      = "demo-php"
            image               = "demo-php:latest"
            container_cpu       = "256"
            container_memory    = "512"
            container_port      = "80"
            host_port           = "80"
            essential           = "true"

            #log driver
            log_driver      = "awslogs"
            awslogs_group   = "/ecs/svc-php-demo"
            awslogs_region  = "us-east-1"
            awslogs_stream_prefix = "ecs"
        }
    ]

    log_driver = [
        {
            log_name            = "/ecs/svc-php-demo"
            retention_in_days   = "3"
            default_tags        = local.default_tags
        }
    ]

    service = [
        {
            name_service        = "svc-demo-php"
            launch_type         = "FARGATE"
            desired_count       = "2"
            platform_version    = "1.4"

            scheduling_strategy         = "REPLICA" 
            deployment_controller_type  = "ECS"

            vpc_id  = "vpc-00000"
            subnets = [ 
                "sn-priv-xxxxxx", 
                "sn-yyyyyy"  
            ]

            container_name  = "demo-php"
            container_port  = "80"

            security_group_mame             = "demo-php-sg"
            security_group_container_port   = "80"
            security_group_cidr_blocks      = [
                "10.40.0.0/21"
            ]
            assign_public_ip                = "false"
        }
    ]

    service_auto_scaling = [
        {
            policy_type         = "TargetTrackingScaling"
            metric_type         = "ECSServiceAverageCPUUtilization"
            scale_in_cooldown   = "300"
            scale_out_cooldown  = "300"
            target_value        = "75"
            max_capacity        = "6"
            min_capacity        = "2"
        }
    ]

    service_load_balancing = [
        {
            name        = "app-demo-php"
            internal    = "false"
            target_type = "ip"
            port        = "80"
            protocol    = "HTTP"
            
            vpc_id      = "vpc-00000"
            subnets     = [ 
                "sn-",
                "sn-"
            ]

            security_group_mame         = "alb-demo-php-sg"
            security_group_lb_port      = "80"
            security_group_cidr_blocks  = [
                "0.0.0.0/0"
            ]
        }
    ]

    default_tags = local.default_tags
}
``` 

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Variables Inputs
| Name | Description | Required | Type | Default |
| ---- | ----------- | --------- | ---- | ------- |
| cluster_name | O nome do cluster. | `yes` | `string` | ` ` |
| cluster_type | O tipo que será inicializado o cluster. Valores validos, FARGATE e EC2. | `yes` | `string` | `FARGATE` |
| task_definition | O bloco task_definition é necessario para rodar containers Dockers em ECS. Segue detalhes abaixo. | `yes` | `list` | `[ ]` |
| capacity_providers | Lista de um ou mais provedores de capacidade para associar ao cluster. Valores validos, FARGATE e FARGATE_SPOT. | `no` | `list` | `[ ]` |
| default_capacity_provider_strategy | Capacity Provider Strategy para ser usado por default para o cluster. Segue detalhes abaixo.  | `no` | `list` | `[ ]` |


O bloco task_definition quando usado, é esperado os seguintes argumentos;

 - `family` - Um nome exclusivo para criar uma task definition
 - `requires_compatibilities` - O tipo de inicialização exigidos pela task. Valores validos; 'FARGATE' e 'EC2'.
 - `cpu` - O numero de cpu usada pela task.
 - `memory` - O numero de memoria em MiB usada pela task.
 - `network_mode` - O modo de rede Docker a ser usado para o container na task. Valor valido para cluster type Fargate; `awsvpc`.  
 - `container_name` - O nome do container.
 - `image` - O docker image a ser usado pelo container
 - `container_port` - A porta do container.
 - `host_port` - A porta do host para o container.
 - `container_cpu` - 
 - `container_memory` - 
 - `essential` - 
 - `log_driver` - 
 - `awslogs_group` - 
 - `awslogs_region` - 
 - `awslogs_stream_prefix` - 


 
## Variable Outputs
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
| Name | Description |
| ---- | ----------- |