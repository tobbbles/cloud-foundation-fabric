/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# tfdoc:file:description Team stages resources.

# top-level teams folder and service account

module "branch-teams-folder" {
  source = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/folder?ref=v12.0.0"
  parent = "organizations/${var.organization.id}"
  name   = "Teams"
}

module "branch-teams-prod-sa" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v12.0.0"
  project_id  = var.automation_project_id
  name        = "resman-teams-0"
  description = "Terraform resman production service account."
  prefix      = local.prefixes.prod
}

# Team-level folders, service accounts and buckets for each individual team

module "branch-teams-team-folder" {
  source    = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/folder?ref=v12.0.0"
  for_each  = coalesce(var.team_folders, {})
  parent    = module.branch-teams-folder.id
  name      = each.value.descriptive_name
  group_iam = each.value.group_iam == null ? {} : each.value.group_iam
}

module "branch-teams-team-sa" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v12.0.0"
  for_each    = coalesce(var.team_folders, {})
  project_id  = var.automation_project_id
  name        = "teams-${each.key}-0"
  description = "Terraform team ${each.key} service account."
  prefix      = local.prefixes.prod
  iam = {
    "roles/iam.serviceAccountTokenCreator" = (
      each.value.impersonation_groups == null
      ? []
      : [for g in each.value.impersonation_groups : "group:${g}"]
    )
  }
}

module "branch-teams-team-gcs" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs?ref=v12.0.0"
  for_each   = coalesce(var.team_folders, {})
  project_id = var.automation_project_id
  name       = "teams-${each.key}-0"
  prefix     = local.prefixes.prod
  versioning = true
  iam = {
    "roles/storage.objectAdmin" = [module.branch-teams-team-sa[each.key].iam_email]
  }
}

# environment: development folder and project factory automation resources

module "branch-teams-team-dev-folder" {
  source   = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/folder?ref=v12.0.0"
  for_each = coalesce(var.team_folders, {})
  parent   = module.branch-teams-team-folder[each.key].id
  # naming: environment descriptive name
  name = "${module.branch-teams-team-folder[each.key].name} - Development"
  # environment-wide human permissions on the whole teams environment
  group_iam = {}
  iam = {
    # remove owner here and at project level if SA does not manage project resources
    "roles/owner" = [
      module.branch-teams-dev-projectfactory-sa.iam_email
    ]
    "roles/logging.admin" = [
      module.branch-teams-dev-projectfactory-sa.iam_email
    ]
    "roles/resourcemanager.folderAdmin" = [
      module.branch-teams-dev-projectfactory-sa.iam_email
    ]
    "roles/resourcemanager.projectCreator" = [
      module.branch-teams-dev-projectfactory-sa.iam_email
    ]
  }
}

moved {
  from = module.branch-teams-project-factory-sa["dev"]
  to   = module.branch-teams-dev-projectfactory-sa
}

module "branch-teams-dev-projectfactory-sa" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v12.0.0"
  project_id = var.automation_project_id
  name       = "resman-pf-0"
  # naming: environment in description
  description = "Terraform project factory development service account."
  prefix      = local.prefixes.dev
}

moved {
  from = module.branch-teams-project-factory-gcs["dev"]
  to   = module.branch-teams-dev-projectfactory-gcs
}

module "branch-teams-dev-projectfactory-gcs" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs?ref=v12.0.0"
  project_id = var.automation_project_id
  name       = "resman-pf-0"
  prefix     = local.prefixes.dev
  versioning = true
  iam = {
    "roles/storage.objectAdmin" = [module.branch-teams-dev-projectfactory-sa.iam_email]
  }
}

# environment: production folder and project factory automation resources

module "branch-teams-team-prod-folder" {
  source   = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/folder?ref=v12.0.0"
  for_each = coalesce(var.team_folders, {})
  parent   = module.branch-teams-team-folder[each.key].id
  # naming: environment descriptive name
  name = "${module.branch-teams-team-folder[each.key].name} - Production"
  # environment-wide human permissions on the whole teams environment
  group_iam = {}
  iam = {
    # remove owner here and at project level if SA does not manage project resources
    "roles/owner" = [
      module.branch-teams-prod-projectfactory-sa.iam_email
    ]
    "roles/logging.admin" = [
      module.branch-teams-prod-projectfactory-sa.iam_email
    ]
    "roles/resourcemanager.folderAdmin" = [
      module.branch-teams-prod-projectfactory-sa.iam_email
    ]
    "roles/resourcemanager.projectCreator" = [
      module.branch-teams-prod-projectfactory-sa.iam_email
    ]
  }
}

moved {
  from = module.branch-teams-project-factory-sa["prod"]
  to   = module.branch-teams-prod-projectfactory-sa
}

module "branch-teams-prod-projectfactory-sa" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v12.0.0"
  project_id = var.automation_project_id
  name       = "resman-pf-0"
  # naming: environment in description
  description = "Terraform project factory production service account."
  prefix      = local.prefixes.prod
}

moved {
  from = module.branch-teams-project-factory-gcs["prod"]
  to   = module.branch-teams-prod-projectfactory-gcs
}

module "branch-teams-prod-projectfactory-gcs" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs?ref=v12.0.0"
  project_id = var.automation_project_id
  name       = "resman-pf-0"
  prefix     = local.prefixes.prod
  versioning = true
  iam = {
    "roles/storage.objectAdmin" = [module.branch-teams-prod-projectfactory-sa.iam_email]
  }
}