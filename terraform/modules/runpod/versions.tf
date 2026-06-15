terraform {
  required_version = ">= 1.6.0"
  required_providers {
    # RunPod has no first-party Terraform provider; we drive the public GraphQL
    # API via the http provider for any resources that need lifecycle management,
    # and surface the API key as a sensitive output for downstream consumers
    # (e.g. CI jobs, Akash deployments, runpod-cli wrappers).
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.0"
    }
  }
}
