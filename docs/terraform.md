<!-- markdownlint-disable -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 4.7 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 4.7 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alb-ingress-prometheus"></a> [alb-ingress-prometheus](#module\_alb-ingress-prometheus) | git::ssh://git@gitlab.com/miquido/terraform/terraform-alb-ingress.git | 3.1.18 |
| <a name="module_ecs-alb-task-prometheus"></a> [ecs-alb-task-prometheus](#module\_ecs-alb-task-prometheus) | git::ssh://git@gitlab.com/miquido/terraform/terraform-ecs-alb-task.git | 5.6.24 |
| <a name="module_prometheus-service-discovery"></a> [prometheus-service-discovery](#module\_prometheus-service-discovery) | git::https://github.com/cloudposse/terraform-aws-ecs-container-definition.git | 0.58.1 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_role_policy.service-discovery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_route53_record.prometheus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.prometheus-ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_iam_policy_document.service-discovery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb"></a> [alb](#input\_alb) | Alb module from ssh://git@gitlab.com/miquido/terraform/terraform-alb.git | <pre>object({<br>    http_listener_arn  = string<br>    https_listener_arn = string<br>    alb_arn_suffix     = string<br>    alb_dns_name       = string<br>    alb_zone_id        = string<br>  })</pre> | `null` | no |
| <a name="input_app_mesh_aws_service_discovery_private_dns_namespace"></a> [app\_mesh\_aws\_service\_discovery\_private\_dns\_namespace](#input\_app\_mesh\_aws\_service\_discovery\_private\_dns\_namespace) | app mesh private DNS namespace | <pre>object({<br>    name        = string<br>    id          = string<br>    hosted_zone = string<br>  })</pre> | `null` | no |
| <a name="input_app_mesh_id"></a> [app\_mesh\_id](#input\_app\_mesh\_id) | n/a | `string` | `null` | no |
| <a name="input_app_mesh_route53_zone"></a> [app\_mesh\_route53\_zone](#input\_app\_mesh\_route53\_zone) | app\_mesh route zone to create service entry | <pre>object({<br>    id   = string<br>    name = string<br>  })</pre> | `null` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS Region | `string` | n/a | yes |
| <a name="input_aws_service_discovery_private_dns_namespace"></a> [aws\_service\_discovery\_private\_dns\_namespace](#input\_aws\_service\_discovery\_private\_dns\_namespace) | n/a | <pre>object({<br>    name        = string<br>    id          = string<br>    hosted_zone = string<br>  })</pre> | `null` | no |
| <a name="input_domain"></a> [domain](#input\_domain) | domain under which prometheus will be available. Required when alb is used | `string` | `null` | no |
| <a name="input_ecs_cluster"></a> [ecs\_cluster](#input\_ecs\_cluster) | resource aws\_ecs\_cluster where to deploy service | <pre>object({<br>    arn  = string<br>    name = string<br>  })</pre> | n/a | yes |
| <a name="input_enable_app_mesh"></a> [enable\_app\_mesh](#input\_enable\_app\_mesh) | Should appmesh resources be created. Required vars: aws\_service\_discovery\_private\_dns\_namespace, aws\_appmesh\_mesh\_id, mesh\_route53\_zone\_id | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name | `any` | n/a | yes |
| <a name="input_ingress_priority"></a> [ingress\_priority](#input\_ingress\_priority) | The priority for the rules without authentication, between 1 and 50000 (1 being highest priority). Must be different from `authenticated_priority` since a listener can't have multiple rules with the same priority | `number` | `89` | no |
| <a name="input_project"></a> [project](#input\_project) | Account/Project Name | `string` | n/a | yes |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | route id to create prometheus entry | `string` | `null` | no |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | Name under which service will be deployed | `string` | `"prometheus"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Default tags to apply on all created resources | `map(string)` | `{}` | no |
| <a name="input_task_cpu"></a> [task\_cpu](#input\_task\_cpu) | ECS task cpu for prometheus | `number` | `256` | no |
| <a name="input_task_memory"></a> [task\_memory](#input\_task\_memory) | ECS task memory for prometheus | `number` | `512` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | VPC module ssh://git@gitlab.com/miquido/terraform/terraform-vpc.git | <pre>object({<br>    vpc_main_security_group_id = string<br>    vpc_id                     = string<br>    private_subnet_ids         = list(string)<br>  })</pre> | n/a | yes |

## Outputs

No outputs.
<!-- markdownlint-restore -->
