provider "aws" {
  region = "us-east-1"
}

locals {
  top_domain                = "example.com"
  domain_prefix             = "stage"
  prometheus_service_name   = "prometheus"
  prometheus_service_prefix = local.domain_prefix != "" ? "${local.prometheus_service_name}.${local.domain_prefix}" : local.prometheus_service_name
  prometheus_service_domain = "${local.prometheus_service_prefix}.${local.top_domain}"
}

module "prometheus" {
  source     = "../../"
  aws_region = "eu-west-1" // var.aws_region
  ecs_cluster = {          // aws_ecs_cluster.main
    arn  = "arn::test::test"
    name = "main"
  }
  project = "example" // var.project
  vpc = {             // module.vpc
    vpc_main_security_group_id = "test_id"
    vpc_id                     = "test_id"
    private_subnet_ids         = ["test_id"]
    vpc_main_security_group_id = "test_id"
  }
  environment = "stage" //var.environment

  /*********** Optional app mesh ************/
  aws_service_discovery_private_dns_namespace = { // aws_service_discovery_private_dns_namespace.map
    name        = "test"
    id          = "test"
    hosted_zone = "test"
  }
  aws_appmesh_mesh_id  = "test" // aws_appmesh_mesh.service.id
  mesh_route53_zone_id = "test" // aws_route53_zone.mesh_private_zone.zone_id

  /*********** Optional alb ************/
  route53_zone_id = "test" //aws_route53_zone.default.zone_id
  alb = {                  // module.alb
    http_listener_arn  = "test"
    https_listener_arn = "test"
    alb_arn_suffix     = "test"
    alb_dns_name       = "test"
    alb_zone_id        = "test"
  }
  domain = "test" // local.prometheus_service_domain
}
