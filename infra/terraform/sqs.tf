# Dead-Letter Queue (DLQ) para isolar mensagens com falha persistente
resource "aws_sqs_queue" "pedidos_dlq" {
  name                      = "pedidos-processamento-dlq"
  message_retention_seconds = 1209600 # 14 dias (tempo maximo para analise humana)

  tags = {
    Environment = "lab"
    Project     = "orders-event-driven"
  }
}

# Fila principal de processamento de pedidos
resource "aws_sqs_queue" "pedidos_processamento" {
  name                       = "pedidos-processamento-queue"
  visibility_timeout_seconds = 60     # 6x o timeout da Lambda (10s)
  message_retention_seconds  = 345600 # 4 dias padrao

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.pedidos_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Environment = "lab"
    Project     = "orders-event-driven"
  }
}

# Fila para o servico de notificacoes
resource "aws_sqs_queue" "pedidos_notificacao" {
  name                       = "pedidos-notificacao-queue"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600 # 4 dias padrao

  tags = {
    Environment = "lab"
    Project     = "orders-event-driven"
  }
}

# Politica de permissao para o SNS enviar mensagens na fila de processamento
resource "aws_sqs_queue_policy" "processamento_policy" {
  queue_url = aws_sqs_queue.pedidos_processamento.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSPublish"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.pedidos_processamento.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.pedidos_topico.arn
          }
        }
      }
    ]
  })
}

# Politica de permissao para o SNS enviar mensagens na fila de notificacao
resource "aws_sqs_queue_policy" "notificacao_policy" {
  queue_url = aws_sqs_queue.pedidos_notificacao.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSPublish"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.pedidos_notificacao.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.pedidos_topico.arn
          }
        }
      }
    ]
  })
}