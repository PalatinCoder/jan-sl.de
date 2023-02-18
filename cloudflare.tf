terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
  }
}

provider "cloudflare" {
  # token pulled from $CLOUDFLARE_API_TOKEN
}

variable "account_id" {
  default = "735c4e000fc0c9e7c45d9cd924ee3f4f"
}

variable "project_name" {
  default = "jan-sl"
}

variable "hugo_version" {
  default = "0.110.0"
}

variable "production_branch" {
  default = "2020"
}

resource "cloudflare_pages_project" "jan-sl" {
  account_id        = var.account_id
  name              = var.project_name
  production_branch = var.production_branch

  build_config {
    build_command   = "hugo"
    destination_dir = "public"
  }
  deployment_configs {
    preview {
      environment_variables = {
        HUGO_VERSION = var.hugo_version
      }
    }
    production {
      environment_variables = {
        HUGO_VERSION = var.hugo_version
      }
    }
  }
  source {
    type = "github"
    config {
      owner                      = "PalatinCoder"
      repo_name                  = "jan-sl.de"
      production_branch          = var.production_branch
      preview_deployment_setting = "none"
      preview_branch_includes    = ["*"]
      preview_branch_excludes    = ["2018"]
    }
  }
}

resource "cloudflare_pages_domain" "about_jan-sl_tech" {
  account_id   = var.account_id
  project_name = var.project_name
  domain       = "about.jan-sl.tech"
}
resource "cloudflare_pages_domain" "www_jan-sl_de" {
  account_id   = var.account_id
  project_name = var.project_name
  domain       = "www.jan-sl.de"
}

resource "cloudflare_record" "about-jan-sl-tech" {
  zone_id     = "1375bf40d92ecc1cc79ae54378f4d2ad"
  name        = "about"
  value       = "${var.project_name}.pages.dev"
  type        = "CNAME"
}
resource "cloudflare_record" "www_jan-sl_tech" {
  zone_id     = "1375bf40d92ecc1cc79ae54378f4d2ad"
  name        = "www"
  type        = "CNAME"
  value       = "about.jan-sl.tech"
  proxied     = true
}
resource "cloudflare_record" "jan-sl_tech" {
  zone_id     = "1375bf40d92ecc1cc79ae54378f4d2ad"
  name        = "jan-sl.tech"
  type        = "CNAME"
  value       = "about.jan-sl.tech"
  proxied     = true
}
resource "cloudflare_ruleset" "jan-sl_tech_canonical_url" {
  zone_id     = "1375bf40d92ecc1cc79ae54378f4d2ad"
  name        = "personal homepage redirects"
  kind        = "zone"
  phase       = "http_request_dynamic_redirect"

  rules {
    action = "redirect"
    action_parameters {
      from_value {
        status_code = 301
        target_url {
          value = "https://about.jan-sl.tech"
        }
        preserve_query_string = false
      }
    }
    expression  = "(http.host eq \"jan-sl.tech\") or (http.host eq \"www.jan-sl.tech\")"
    description = "Redirect anyone on the root domains to the canonical URL of the personal homepage"
    enabled     = true
  }
}
