SHELL := /usr/bin/env bash

.PHONY: setup akash terraform-init terraform-apply deploy-all

setup:
	cp -n .env.example .env || true
	cp -n terraform.tfvars.example terraform.tfvars || true

akash:
	bash ./scripts/akash-deploy.sh

terraform-init:
	terraform init

terraform-apply:
	terraform apply -var-file=terraform.tfvars

deploy-all: setup akash terraform-init terraform-apply
