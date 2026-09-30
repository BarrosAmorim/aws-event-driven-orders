output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB de pedidos"
  value       = aws_dynamodb_table.pedidos.name
}

output "dynamodb_table_arn" {
  description = "ARN da tabela DynamoDB de pedidos"
  value       = aws_dynamodb_table.pedidos.arn
}
