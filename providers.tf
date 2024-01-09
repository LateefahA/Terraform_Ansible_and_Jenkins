terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region                   = "us-west-2"
  shared_config_files      = ["path_to_config_file"]
  shared_credentials_files = ["path_to_credentials"]
  profile                  = "profile_name"
}
