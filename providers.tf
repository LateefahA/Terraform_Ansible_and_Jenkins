terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region                   = "us-west-2"
  shared_config_files      = ["/home/lateefat/.aws/config"]
  shared_credentials_files = ["/home/lateefat/.aws/credentials"]
  profile                  = "vscode"
}
