# Topico SNS para publicacao de eventos de pedidos
resource "aws_sns_topic" "pedidos_topico" {
  name = "pedidos-topic"

  tags = {
    Environment = "lab"
    Project     = "orders-event-driven"
  }
}

# Subscricao Fan-out para a fila de processamento
resource "aws_sns_topic_subscription" "processamento_sub" {
  topic_arn            = aws_sns_topic.pedidos_topico.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.pedidos_processamento.arn
  raw_message_delivery = true
}

# Subscricao Fan-out para a fila de notificacao
resource "aws_sns_topic_subscription" "notificacao_sub" {
  topic_arn            = aws_sns_topic.pedidos_topico.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.pedidos_notificacao.arn
  raw_message_delivery = true
}

