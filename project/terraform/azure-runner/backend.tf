terraform {
  backend "s3" {
    bucket = "devopsbackend911azure-runner"
    key    = "infra/aws.tfstate"
    region = "us-east-1"
  }
}
