output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB de pedidos"
  value       = aws_dynamodb_table.pedidos.name
}

output "dynamodb_table_arn" {
  description = "ARN da tabela DynamoDB de pedidos"
  value       = aws_dynamodb_table.pedidos.arn
}

# Outputs da Etapa 3: Mensageria e Resiliencia
output "sns_topic_pedidos_arn" {
  description = "ARN do topico SNS de pedidos"
  value       = aws_sns_topic.pedidos_topico.arn
}

output "sqs_processamento_queue_arn" {
  description = "ARN da fila SQS de processamento de pedidos"
  value       = aws_sqs_queue.pedidos_processamento.arn
}

output "sqs_processamento_queue_url" {
  description = "URL da fila SQS de processamento de pedidos"
  value       = aws_sqs_queue.pedidos_processamento.id
}

output "sqs_notificacao_queue_arn" {
  description = "ARN da fila SQS de notificacao de pedidos"
  value       = aws_sqs_queue.pedidos_notificacao.arn
}

output "sqs_notificacao_queue_url" {
  description = "URL da fila SQS de notificacao de pedidos"
  value       = aws_sqs_queue.pedidos_notificacao.id
}

output "sqs_dlq_arn" {
  description = "ARN da Dead-Letter Queue (DLQ)"
  value       = aws_sqs_queue.pedidos_dlq.arn
}

output "sqs_dlq_url" {
  description = "URL da Dead-Letter Queue (DLQ)"
  value       = aws_sqs_queue.pedidos_dlq.id
}
