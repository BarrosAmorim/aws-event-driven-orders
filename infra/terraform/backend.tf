terraform {
  backend "s3" {
    bucket       = "terraform-state-rafael-pedidos-event-driven"
    key          = "pedidos-event-driven/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
