locals {
  prometheus_service_port              = 9090
  prometheus_service_health_check_path = "/-/healthy"
  prometheus_service_image_repository  = "miquidocompany/prometheus"
  prometheus_service_image_tag         = "1.0.0"
  appmesh_prometheus_service_dns       = "${var.service_name}.${local.appmesh_domain}"
  appmesh_prometheus_cloud_map_dns     = var.aws_service_discovery_private_dns_namespace != null ? replace(local.appmesh_prometheus_service_dns, local.appmesh_domain, var.aws_service_discovery_private_dns_namespace.name) : null
  appmesh_domain                       = "${var.environment}.app.mesh.local"

  alb_target_group_arn = join("", module.alb-ingress-prometheus.*.target_group_arn)
  app_mesh_count       = var.aws_service_discovery_private_dns_namespace != null && var.aws_appmesh_mesh_id != null && var.mesh_route53_zone_id != null ? 1 : 0
}

module "alb-ingress-prometheus" {
  count       = var.alb != null ? 1 : 0
  source      = "git::ssh://git@gitlab.com/miquido/terraform/terraform-alb-ingress.git?ref=tags/3.1.8"
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

module "prometheus-service-discovery" {
  source = "git::https://github.com/cloudposse/terraform-aws-ecs-container-definition.git?ref=tags/0.57.0"

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
    sid = "Prometheus"

    effect = "Allow"

    actions = [
      "ecs:*"
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

module "ecs-alb-task-prometheus-envoy-proxy" {
  count                             = local.app_mesh_count
  source                            = "git::ssh://git@gitlab.com/miquido/terraform/terraform-ecs-envoy.git?ref=tags/1.1.1"
  appmesh-resource-arn              = module.prometheus-appmesh[count.index].appmesh-resource-arn
  awslogs-group                     = module.ecs-alb-task-prometheus.log_group_name
  awslogs-region                    = var.aws_region
  app-ports                         = local.prometheus_service_port
  container_name                    = "${var.project}-${var.environment}-${var.service_name}"
  aws_service_discovery_service_arn = module.prometheus-appmesh[count.index].aws_service_discovery_service_arn
  egress-ignored-ports              = ""
}

module "ecs-alb-task-prometheus" {
  source = "git::ssh://git@gitlab.com/miquido/terraform/terraform-ecs-alb-task.git?ref=tags/5.5.6"

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
    module.prometheus-service-discovery.json_map_encoded,
  join("", module.ecs-alb-task-prometheus-envoy-proxy.*.json_map_encoded)]
  exec_enabled = true

  volumes = [
    {
      name                        = "service-discovery"
      host_path                   = null
      docker_volume_configuration = []
      efs_volume_configuration    = []
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

  service_registries   = length(module.ecs-alb-task-prometheus-envoy-proxy) == 1 ? module.ecs-alb-task-prometheus-envoy-proxy[0].service_registries : []
  container_depends_on = length(module.ecs-alb-task-prometheus-envoy-proxy) == 1 ? [module.ecs-alb-task-prometheus-envoy-proxy[0].container_dependant] : null
  proxy_configuration  = length(module.ecs-alb-task-prometheus-envoy-proxy) == 1 ? module.ecs-alb-task-prometheus-envoy-proxy[0].proxy_configuration : null

  capacity_provider_strategies = [
    {
      capacity_provider = "FARGATE_SPOT"
      weight            = 1
      base              = null
    }
  ]
}

module "prometheus-appmesh" {
  count                    = local.app_mesh_count
  source                   = "git::ssh://git@gitlab.com/miquido/terraform/terraform-app-mesh-service.git?ref=tags/1.0.1"
  app_health_check_path    = local.prometheus_service_health_check_path
  app_port                 = local.prometheus_service_port
  appmesh_domain           = local.appmesh_domain
  appmesh_name             = var.aws_appmesh_mesh_id
  appmesh_service_name     = var.service_name
  cloud_map_dns            = local.appmesh_prometheus_cloud_map_dns
  cloud_map_hosted_zone_id = var.aws_service_discovery_private_dns_namespace.hosted_zone
  cloud_map_namespace_name = var.aws_service_discovery_private_dns_namespace.name
  map_id                   = var.aws_service_discovery_private_dns_namespace.id
  tags                     = var.tags
  task_role_name           = module.ecs-alb-task-prometheus.task_role_name
  zone_id                  = var.mesh_route53_zone_id
}
