locals {
    config = yamldecode(file("env-config.yaml"))
}

provider "aws" {
    region = local.config.region
    default_tags {
        tags = {
            project = local.config.project
        }
    }
}

module "chaos" {
    source = "./modules/chaos"
    config = local.config
}

module "example" {
  source = "./modules/example"
  config = local.config
}