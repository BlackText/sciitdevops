terraform {
  backend "s3" {
    bucket = "devopsbackend911"
    key    = "infra/aws.tfstate"
    region = "us-east-1"
  }
}