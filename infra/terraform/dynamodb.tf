resource "aws_dynamodb_table" "pedidos" {
  name         = "${var.project_name}-pedidos-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pedido_id"

  attribute {
    name = "pedido_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = false
  }

  tags = {
    Name = "${var.project_name}-pedidos-${var.environment}"
  }
}
