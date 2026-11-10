# Etapa 05 — Implementação e Integração das Lambdas Assíncronas (Consumidores SQS)

## 1. Objetivo da Etapa
Implementar, empacotar via Terraform e validar os consumidores assíncronos da arquitetura orientada a eventos (EDA) do projeto:
- **`lambda_processar_pedido`**: Consumidor da fila `pedidos-processamento-queue` responsável por atualizar o status do pedido no DynamoDB para `COMPLETED` e fornecer gatilho para testes de falha na DLQ.
- **`lambda_notificar_pedido`**: Consumidor da fila `pedidos-notificacao-queue` responsável por simular o envio de confirmação ao cliente via logs estruturados no Amazon CloudWatch.
- **Integração ESM (Event Source Mapping)**: Conectar as filas SQS diretamente às funções Lambda mantendo a resiliência e a proporção de timeouts definida na arquitetura.

---

## 2. Decisões Arquiteturais e de Engenharia
- **Event Source Mapping (ESM):** Utilização do polling nativo gerenciado da AWS Lambda para consumir mensagens em lotes (`batch_size = 10`), garantindo escala automática sem necessidade de gerenciar instâncias de consumidores.
- **Proporção de Timeouts (1:6):** Manutenção do timeout das funções Lambda em 10 segundos contra 60 segundos de `VisibilityTimeout` nas filas SQS, prevenindo reprocessamento antecipado de mensagens ainda em execução.
- **Desempacotamento Polimórfico de Envelopes:** Tratamento automático de mensagens envelopadas pelo SNS (formato JSON dentro do atributo `Message`) e mensagens injetadas diretamente na fila SQS.
- **Simulação de Falha para DLQ:** Interceptação do identificador `cliente_id == "simular_falha_dlq"` para forçar exceções intencionais e validar o descarte na Dead-Letter Queue (DLQ).
- **Empacotamento Automatizado via Terraform:** Uso do provider `archive_file` com cálculo de hash SHA256 (`source_code_hash`) apontando diretamente para os diretórios individuais em `src/`, garantindo builds reproduzíveis e imutáveis.

---

## 3. Ações Executadas (Passo a Passo)

### Ação 5.1 — Criação do utilitário comum `src/common/utils.py`
- **Intenção:** Criar funções auxiliares reutilizáveis para padronização de respostas HTTP e desempacotamento de mensagens SQS/SNS.
- **Comando executado:**
cat << 'EOF' > src/common/utils.py
import json
import logging

logger = logging.getLogger()


def build_response(status_code: int, body: dict) -> dict:
    """Padroniza a resposta HTTP para os endpoints integrados ao API Gateway."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }


def parse_sqs_message(record_body: str) -> dict:
    """Desempacota a carga útil recebida, tratando envelopes SNS ou entrega direta SQS."""
    payload = json.loads(record_body)
    if "Message" in payload and isinstance(payload["Message"], str):
        return json.loads(payload["Message"])
    return payload
EOF
- **Validação:** Arquivo criado e validado no diretório compartilhado.

---

### Ação 5.2 — Implementação da Lambda Consumidora de Notificação
- **Intenção:** Criar o handler da função responsável por processar os eventos da fila `pedidos-notificacao-queue`.
- **Comando executado:**
cat << 'EOF' > src/lambda_notificar_pedido/handler.py
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(os.getenv("LOG_LEVEL", "INFO"))


def extrair_corpo_evento(record_body: str) -> dict:
    payload = json.loads(record_body)
    if "Message" in payload and isinstance(payload["Message"], str):
        return json.loads(payload["Message"])
    return payload


def lambda_handler(event, context):
    records = event.get("Records", [])
    logger.info("Consumidor de notificacao iniciado com %d registros.", len(records))

    for record in records:
        message_id = record.get("messageId")
        body_raw = record.get("body", "{}")

        try:
            dados_evento = extrair_corpo_evento(body_raw)
            dados_pedido = dados_evento.get("dados", dados_evento)

            pedido_id = dados_pedido.get("pedido_id")
            cliente_id = dados_pedido.get("cliente_id")
            valor_total = dados_pedido.get("valor_total")

            msg_log = (
                f"[SIMULACAO DE NOTIFICACAO] Pedido: {pedido_id} | "
                f"Cliente: {cliente_id} | Valor: {valor_total} | "
                "Mensagem: Pedido recebido e em processamento."
            )
            logger.info(msg_log)

        except Exception as e:
            logger.error("Falha no registro %s: %s", message_id, str(e))
            raise e

    return {"statusCode": 200, "body": "Notificacoes processadas com sucesso."}
EOF
- **Validação:** Código gravado e formatado sem violações de sintaxe.

---

### Ação 5.3 — Implementação da Lambda Consumidora de Processamento
- **Intenção:** Criar o handler que consome a fila `pedidos-processamento-queue` e atualiza o DynamoDB para `COMPLETED`.
- **Comando executado:**
cat << 'EOF' > src/lambda_processar_pedido/handler.py
import json
import logging
import os
from datetime import UTC, datetime

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(os.getenv("LOG_LEVEL", "INFO"))

DYNAMODB_TABLE = os.getenv("DYNAMODB_TABLE", "pedidos-event-driven-pedidos-dev")
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(DYNAMODB_TABLE)


def extrair_corpo_evento(record_body: str) -> dict:
    payload = json.loads(record_body)
    if "Message" in payload and isinstance(payload["Message"], str):
        return json.loads(payload["Message"])
    return payload


def lambda_handler(event, context):
    records = event.get("Records", [])
    logger.info("Processamento de lote iniciado com %d registros.", len(records))

    for record in records:
        message_id = record.get("messageId")
        body_raw = record.get("body", "{}")

        try:
            dados_evento = extrair_corpo_evento(body_raw)
            dados_pedido = dados_evento.get("dados", dados_evento)

            pedido_id = dados_pedido.get("pedido_id")
            cliente_id = dados_pedido.get("cliente_id")

            if not pedido_id:
                logger.error("Registro %s ignorado: pedido_id ausente no payload.", message_id)
                continue

            logger.info("Processando pedido %s para o cliente %s.", pedido_id, cliente_id)

            if cliente_id == "simular_falha_dlq":
                logger.warning("Simulação de falha acionada para o pedido %s.", pedido_id)
                raise RuntimeError(f"Falha forçada para teste de DLQ no pedido {pedido_id}")

            agora_iso = datetime.now(UTC).isoformat()

            table.update_item(
                Key={"pedido_id": pedido_id},
                UpdateExpression="SET #st = :status, atualizado_em = :atualizado",
                ExpressionAttributeNames={"#st": "status"},
                ExpressionAttributeValues={
                    ":status": "COMPLETED",
                    ":atualizado": agora_iso,
                },
            )

            logger.info("Pedido %s atualizado com sucesso para COMPLETED.", pedido_id)

        except ClientError as e:
            logger.error("Erro DynamoDB ao processar registro %s: %s", message_id, str(e))
            raise e
        except Exception as e:
            logger.error("Erro inesperado ao processar registro %s: %s", message_id, str(e))
            raise e

    return {"statusCode": 200, "body": "Lote processado com sucesso."}
EOF
- **Validação:** Código validado com a biblioteca `boto3` e tipagem de datas UTC nativa do Python 3.12.

---

### Ação 5.4 — Configuração da Infraestrutura no Terraform (`infra/terraform/lambda.tf`)
- **Intenção:** Configurar os recursos de empacotamento (`archive_file`), as duas funções Lambda e os mapeamentos de evento (`aws_lambda_event_source_mapping`).
- **Comando executado:**
cat << 'EOF' > infra/terraform/lambda.tf
# Empacotamento
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

# Lambda Processar Pedido
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

resource "aws_lambda_event_source_mapping" "sqs_processar_trigger" {
  event_source_arn = aws_sqs_queue.pedidos_processamento.arn
  function_name    = aws_lambda_function.processar_pedido.arn
  batch_size       = 10
  enabled          = true
}

# Lambda Notificar Pedido
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

resource "aws_lambda_event_source_mapping" "sqs_notificar_trigger" {
  event_source_arn = aws_sqs_queue.pedidos_notificacao.arn
  function_name    = aws_lambda_function.notificar_pedido.arn
  batch_size       = 10
  enabled          = true
}
EOF
- **Validação:** Arquivo salvo com sintaxe HCL2 e referências alinhadas às declarações de IAM Roles e Filas SQS.

---

### Ação 5.5 — Checagem de Estilo e Linting com Ruff
- **Intenção:** Validar que todo o código Python segue os padrões estritos configurados no `pyproject.toml`.
- **Comando executado:**
source .venv/bin/activate && ruff check --fix src/
- **Saída do terminal:**
Found 1 error (1 fixed, 0 remaining).
- **Validação:** Todas as importações ordenadas e linhas longas corrigidas. Código 100% aderente ao linter.

---

### Ação 5.6 — Confirmação de Identidade e Provisionamento na AWS
- **Intenção:** Garantir a execução sob as credenciais corretas e provisionar a infraestrutura completa.
- **Comandos executados:**
aws sts get-caller-identity
cd infra/terraform && terraform apply -auto-approve
- **Saída do terminal:**
"Account": "696537703431",
"Arn": "arn:aws:iam::696537703431:user/Barros"

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

---

### Ação 5.7 — Validação Integrada Ponta a Ponta

#### 1. Inserção do Pedido Base no DynamoDB
- **Comando executado:**
aws dynamodb put-item \
  --table-name "pedidos-event-driven-pedidos-dev" \
  --item '{
    "pedido_id": {"S": "pedido-teste-etapa5"},
    "cliente_id": {"S": "cliente-teste-123"},
    "status": {"S": "PENDING"},
    "criado_em": {"S": "2026-11-09T22:00:00Z"}
  }'

#### 2. Publicação da Mensagem de Evento na Fila SQS
- **Comando executado:**
aws sqs send-message \
  --queue-url "https://sqs.us-east-1.amazonaws.com/696537703431/pedidos-processamento-queue" \
  --message-body '{
    "evento_tipo": "PEDIDO_CRIADO",
    "dados": {
      "pedido_id": "pedido-teste-etapa5",
      "cliente_id": "cliente-teste-123",
      "valor_total": "150.00"
    }
  }'
- **Saída:**
{
    "MD5OfMessageBody": "c22e40164a6bcc6b2867a6fcb9320fff",
    "MessageId": "bf6d782a-694a-4dbb-990f-85a89d4a92a1"
}

#### 3. Validação da Transição de Estado no DynamoDB
- **Comando executado:**
aws dynamodb get-item \
  --table-name "pedidos-event-driven-pedidos-dev" \
  --key '{"pedido_id": {"S": "pedido-teste-etapa5"}}' \
  --no-cli-pager
- **Saída obtida:**
{
    "Item": {
        "atualizado_em": {
            "S": "2026-11-10T01:24:54.729531+00:00"
        },
        "cliente_id": {
            "S": "cliente-teste-123"
        },
        "criado_em": {
            "S": "2026-11-09T22:00:00Z"
        },
        "pedido_id": {
            "S": "pedido-teste-etapa5"
        },
        "status": {
            "S": "COMPLETED"
        }
    }
}

#### 4. Auditoria de Invocação e Logs no CloudWatch
- **Comando executado:**
aws logs filter-log-events \
  --log-group-name "/aws/lambda/pedidos-event-driven-processar-pedido-dev" \
  --limit 5 \
  --no-cli-pager
- **Saída obtida:**
[INFO] Processamento de lote iniciado com 1 registros.
[INFO] Processando pedido pedido-teste-etapa5 para o cliente cliente-teste-123.
[INFO] Pedido pedido-teste-etapa5 atualizado com sucesso para COMPLETED.

---

## 4. Problemas Encontrados e Soluções Aplicadas

| Problema Identificado | Causa Raiz | Solução Aplicada |
| :--- | :--- | :--- |
| `undeclared resource` no `terraform validate` | Nomes incorretos das filas SQS referenciadas no arquivo `lambda.tf`. | Ajustado para os identificadores declarados no `sqs.tf`: `pedidos_processamento` e `pedidos_notificacao`. |
| `Uploaded file must be a non-empty zip` no `terraform apply` | O arquivo `handler.py` de processamento estava com 0 bytes devido a gravação incorreta prévia em outro diretório. | Gravado o código integral no caminho `src/lambda_processar_pedido/handler.py` e recriado o zip no build. |
| Erros `I001` de ordenação de imports no Ruff | Imports do `boto3` e `datetime` sem separação de linhas conforme convenção PEP 8. | Execução de `ruff check --fix src/` no ambiente virtual para correção automática. |
| Travamento do terminal após execução de comandos AWS CLI | Comportamento padrão do pager interativo (`less`) da AWS CLI no Raspberry Pi OS. | Adicionada a flag `--no-cli-pager` em todas as consultas da AWS CLI. |

---

## 5. Teardown e Gestão de Custos (FinOps)
Após a validação prática integral das evidências, foi realizada a limpeza do dado de teste no DynamoDB e a destruição completa da infraestrutura na AWS para garantir custo zero entre as sessões de desenvolvimento:

aws dynamodb delete-item \
  --table-name "pedidos-event-driven-pedidos-dev" \
  --key '{"pedido_id": {"S": "pedido-teste-etapa5"}}'

cd infra/terraform && terraform destroy -auto-approve

- **Saída final de destruição:**
Destroy complete! Resources: 25 destroyed.