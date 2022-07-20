locals {
  prometheus_service_port              = 9090
  prometheus_service_health_check_path = "/-/healthy"
  prometheus_service_image_repository  = "miquidocompany/prometheus"
  prometheus_service_image_tag         = "1.0.0"

  alb_target_group_arn = join("", module.alb-ingress-prometheus.*.target_group_arn)
}

module "alb-ingress-prometheus" {
  count       = var.alb != null ? 1 : 0
  source      = "git::ssh://git@gitlab.com/miquido/terraform/terraform-alb-ingress.git?ref=3.1.18"
  name        = var.service_name
  project     = var.project
  environment = var.environment
  tags        = var.tags
  vpc_id      = var.vpc.vpc_id
  listener_arns = [
    var.alb.http_listener_arn,
    var.alb.https_listener_arn
  ]
  hosts                                      = [var.domain]
  port                                       = local.prometheus_service_port
  health_check_path                          = local.prometheus_service_health_check_path
  health_check_healthy_threshold             = 2
  health_check_interval                      = 20
  health_check_unhealthy_threshold           = 2
  alb_target_group_alarms_enabled            = true
  alb_target_group_alarms_treat_missing_data = "notBreaching"
  alb_arn_suffix                             = var.alb.alb_arn_suffix
  priority                                   = var.ingress_priority
}

resource "aws_route53_record" "prometheus" {
  count   = var.alb != null && var.domain != null ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = var.alb.alb_dns_name
    zone_id                = var.alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "prometheus-ipv6" {
  count   = var.alb != null && var.domain != null ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain
  type    = "AAAA"

  alias {
    name                   = var.alb.alb_dns_name
    zone_id                = var.alb.alb_zone_id
    evaluate_target_health = true
  }
}

module "prometheus-service-discovery" {
  source = "git::https://github.com/cloudposse/terraform-aws-ecs-container-definition.git?ref=0.58.1"

  command = [
    "-config.write-to",
  "/service-discovery/ecs_file_sd.yml"]
  container_image  = "tkgregory/prometheus-ecs-discovery"
  container_name   = "service-discovery"
  container_memory = 256

  log_configuration = {
    logDriver     = "awslogs"
    secretOptions = null
    options = {
      awslogs-region        = var.aws_region
      awslogs-group         = module.ecs-alb-task-prometheus.log_group_name
      awslogs-stream-prefix = "prometheus"
    }
  }
  mount_points = [
    {
      containerPath = "/service-discovery"
      sourceVolume  = "service-discovery"
      readOnly      = false
    }
  ]
}

data "aws_iam_policy_document" "service-discovery" {
  statement {
    sid = "PrometheusECSTasks"

    effect = "Allow"

    actions = [
      "ecs:ListClusters",
      "ecs:ListTasks",
      "ecs:DescribeTask",
      "ecs:DescribeInstances",
      "ecs:DescribeContainerInstances",
      "ecs:DescribeTasks",
      "ecs:DescribeTaskDefinition"
    ]

    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role_policy" "service-discovery" {
  role   = module.ecs-alb-task-prometheus.task_role_name
  policy = data.aws_iam_policy_document.service-discovery.json
}

module "ecs-alb-task-prometheus" {
  source = "git::ssh://git@gitlab.com/miquido/terraform/terraform-ecs-alb-task.git?ref=5.6.26"

  name                     = var.service_name
  project                  = var.project
  environment              = var.environment
  tags                     = var.tags
  container_image          = local.prometheus_service_image_repository
  container_tag            = local.prometheus_service_image_tag
  container_port           = local.prometheus_service_port
  task_cpu                 = var.task_cpu
  task_memory              = var.task_memory
  desired_count            = 1
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 1
  autoscaling_enabled      = false
  ecs_alarms_enabled       = true
  assign_public_ip         = false
  readonly_root_filesystem = false
  logs_region              = var.aws_region
  vpc_id                   = var.vpc.vpc_id
  alb_target_group_arn     = local.alb_target_group_arn
  ecs_default_alb_enabled  = var.alb != null
  ecs_cluster_arn          = var.ecs_cluster.arn
  security_group_ids = [
    var.vpc.vpc_main_security_group_id
  ]
  subnet_ids       = var.vpc.private_subnet_ids
  ecs_cluster_name = var.ecs_cluster.name
  platform_version = "1.4.0"
  additional_containers = [
  module.prometheus-service-discovery.json_map_encoded]
  exec_enabled = true

  docker_volumes = [
    {
      name      = "service-discovery"
      host_path = null
      docker_volume_configuration = [
        {
          scope         = "shared"
          autoprovision = true
          driver        = "local"
          driver_opts   = null
          labels        = null
        }
      ]

    }
  ]

  mount_points = [
    {
      containerPath = "/service-discovery"
      sourceVolume  = "service-discovery"
      readOnly      = false
    }
  ]

  healthcheck = {
    command = [
      "CMD-SHELL",
    "curl -s http://localhost:${local.prometheus_service_port}${local.prometheus_service_health_check_path}"]
    interval    = 20
    retries     = 2
    startPeriod = 100
    timeout     = 2
  }

  app_mesh_enable                                      = var.enable_app_mesh
  app_mesh_aws_service_discovery_private_dns_namespace = var.aws_service_discovery_private_dns_namespace
  app_mesh_id                                          = var.app_mesh_id
  app_mesh_route53_zone                                = var.app_mesh_route53_zone
  app_mesh_health_check_path                           = local.prometheus_service_health_check_path

  capacity_provider_strategies = [
    {
      capacity_provider = "FARGATE_SPOT"
      weight            = 1
      base              = null
    }
  ]
  security_group_description = "Allow ALL egress from ECS service"
}
