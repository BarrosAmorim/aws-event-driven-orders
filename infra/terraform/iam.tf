# Política de confiança que permite ao serviço AWS Lambda assumir as roles de execução
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# -----------------------------------------------------------------------------
# Lambda: Criar Pedido
# -----------------------------------------------------------------------------

# Role de execução da Lambda Criar Pedido
resource "aws_iam_role" "lambda_criar_pedido" {
  name               = "role-lambda-criar-pedido"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Permissão básica para envio de logs ao CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_criar_pedido_logs" {
  role       = aws_iam_role.lambda_criar_pedido.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Política de menor privilégio: PutItem/GetItem no DynamoDB e Publish no SNS
resource "aws_iam_role_policy" "lambda_criar_pedido_policy" {
  name = "policy-lambda-criar-pedido"
  role = aws_iam_role.lambda_criar_pedido.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem"
        ]
        Resource = aws_dynamodb_table.pedidos.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.pedidos_topico.arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Lambda: Consultar Pedido
# -----------------------------------------------------------------------------

# Role de execução da Lambda Consultar Pedido
resource "aws_iam_role" "lambda_consultar_pedido" {
  name               = "role-lambda-consultar-pedido"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Permissão básica para envio de logs ao CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_consultar_pedido_logs" {
  role       = aws_iam_role.lambda_consultar_pedido.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Política de menor privilégio: apenas GetItem no DynamoDB
resource "aws_iam_role_policy" "lambda_consultar_pedido_policy" {
  name = "policy-lambda-consultar-pedido"
  role = aws_iam_role.lambda_consultar_pedido.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem"]
        Resource = aws_dynamodb_table.pedidos.arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Lambda: Processar Pedido
# -----------------------------------------------------------------------------

# Role de execução da Lambda Processar Pedido
resource "aws_iam_role" "lambda_processar_pedido" {
  name               = "role-lambda-processar-pedido"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Permissão básica para envio de logs ao CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_processar_pedido_logs" {
  role       = aws_iam_role.lambda_processar_pedido.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Política de menor privilégio: Consumo da fila SQS de processamento e UpdateItem no DynamoDB
resource "aws_iam_role_policy" "lambda_processar_pedido_policy" {
  name = "policy-lambda-processar-pedido"
  role = aws_iam_role.lambda_processar_pedido.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.pedidos_processamento.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.pedidos.arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Lambda: Notificar Pedido
# -----------------------------------------------------------------------------

# Role de execução da Lambda Notificar Pedido
resource "aws_iam_role" "lambda_notificar_pedido" {
  name               = "role-lambda-notificar-pedido"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Permissão básica para envio de logs ao CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_notificar_pedido_logs" {
  role       = aws_iam_role.lambda_notificar_pedido.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Política de menor privilégio: Consumo exclusivo da fila SQS de notificação
resource "aws_iam_role_policy" "lambda_notificar_pedido_policy" {
  name = "policy-lambda-notificar-pedido"
  role = aws_iam_role.lambda_notificar_pedido.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.pedidos_notificacao.arn
      }
    ]
  })
}

