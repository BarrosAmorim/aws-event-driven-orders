# ==============================================================================
# Empacotamento das Lambdas Consumidoras
# ==============================================================================

data "archive_file" "lambda_processar_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../src/lambda_processar_pedido"
  output_path = "${path.module}/builds/lambda_processar_pedido.zip"
}

data "archive_file" "lambda_notificar_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../src/lambda_notificar_pedido"
  output_path = "${path.module}/builds/lambda_notificar_pedido.zip"
}

# ==============================================================================
# Função Lambda: Processar Pedido (Consumidor SQS)
# ==============================================================================

resource "aws_lambda_function" "processar_pedido" {
  function_name    = "${var.project_name}-processar-pedido-${var.environment}"
  role             = aws_iam_role.lambda_processar_pedido.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_processar_zip.output_path
  source_code_hash = data.archive_file.lambda_processar_zip.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.pedidos.name
      LOG_LEVEL      = "INFO"
    }
  }

  tags = {
    Name        = "${var.project_name}-lambda-processar-${var.environment}"
    Environment = var.environment
  }
}

# Gatilho SQS -> Lambda Processar Pedido
resource "aws_lambda_event_source_mapping" "sqs_processar_trigger" {
  event_source_arn = aws_sqs_queue.pedidos_processamento.arn
  function_name    = aws_lambda_function.processar_pedido.arn
  batch_size       = 10
  enabled          = true
}

# ==============================================================================
# Função Lambda: Notificar Pedido (Consumidor SQS)
# ==============================================================================

resource "aws_lambda_function" "notificar_pedido" {
  function_name    = "${var.project_name}-notificar-pedido-${var.environment}"
  role             = aws_iam_role.lambda_notificar_pedido.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_notificar_zip.output_path
  source_code_hash = data.archive_file.lambda_notificar_zip.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  tags = {
    Name        = "${var.project_name}-lambda-notificar-${var.environment}"
    Environment = var.environment
  }
}

# Gatilho SQS -> Lambda Notificar Pedido
resource "aws_lambda_event_source_mapping" "sqs_notificar_trigger" {
  event_source_arn = aws_sqs_queue.pedidos_notificacao.arn
  function_name    = aws_lambda_function.notificar_pedido.arn
  batch_size       = 10
  enabled          = true
}
