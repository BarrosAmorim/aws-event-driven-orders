# Registro de Execução — Etapa 3: Camada de Mensageria e Resiliência (SNS, SQS e DLQ)

## 1. Objetivo e Problema que Resolve
Implementei a espinha dorsal de comunicação assíncrona orientada a eventos para desacoplar o recebimento de pedidos da execução das regras de negócio e comunicações externas[cite: 1]. Utilizei o padrão Fan-out (um produtor SNS distribuindo cópias idênticas para múltiplos consumidores SQS independentes) e configurei a resiliência do sistema contra mensagens problemáticas (poison pills) através de uma Dead-Letter Queue (DLQ) com tempo de retenção estendido para análise operacional[cite: 1].

---

## 2. O que Foi Criado e Recursos Envolvidos
* **Dead-Letter Queue (`aws_sqs_queue.pedidos_dlq`):** Fila para retenção de mensagens que falharem repetidamente por 14 dias[cite: 1].
* **Fila Principal de Processamento (`aws_sqs_queue.pedidos_processamento`):** Fila com timeout de visibilidade de 60 segundos e política de redirecionamento (redrive) para a DLQ após 3 falhas[cite: 1].
* **Fila de Notificação (`aws_sqs_queue.pedidos_notificacao`):** Fila independente dedicada ao serviço assíncrono de notificações aos clientes[cite: 1].
* **Tópico SNS (`aws_sns_topic.pedidos_topico`):** Barramento central para publicação de eventos de negócio (`PEDIDO_CRIADO`)[cite: 1].
* **Assinaturas Fan-out (`aws_sns_topic_subscription`):** Duas assinaturas SNS-SQS com entrega direta de mensagem (`raw_message_delivery = true`)[cite: 1].
* **Políticas de Acesso das Filas (`aws_sqs_queue_policy`):** Permissões explícitas baseadas em recurso concedendo autorização para o SNS entregar mensagens em ambas as filas SQS[cite: 1].
* **Outputs (`outputs.tf`):** Exportação dos ARNs e URLs gerados para reutilização nas próximas etapas[cite: 1].

---

## 3. Código Terraform Implementado

### A. Arquivo `infra/terraform/sqs.tf`
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
  visibility_timeout_seconds = 60 # 6x o timeout da Lambda (10s)
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
        Sid       = "AllowSNSPublish"
        Effect    = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.pedidos_processamento.arn
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
        Sid       = "AllowSNSPublish"
        Effect    = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.pedidos_notificacao.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.pedidos_topico.arn
          }
        }
      }
    ]
  })
}

 ---
 
### B. Arquivo `infra/terraform/sns.tf`
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

### C. Atualização no `infra/terraform/outputs.tf`
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

---

## 4. Comandos Executados e Onde Foram Executados
Todos os comandos foram executados no diretório: `~/projects/aws-event-driven-orders/infra/terraform`

1. Formatação e Validação:
   terraform fmt && terraform validate
2. Planejamento da Infraestrutura:
   terraform plan
3. Provisionamento na AWS:
   terraform apply
4. Publicação de Teste no SNS:
   aws sns publish \
     --topic-arn $(terraform output -raw sns_topic_pedidos_arn) \
     --message '{"evento_tipo": "TESTE_FANOUT", "status": "OK"}'
5. Leitura na Fila de Processamento:
   aws sqs receive-message \
     --queue-url $(terraform output -raw sqs_processamento_queue_url) \
     --max-number-of-messages 1
6. Leitura na Fila de Notificação:
   aws sqs receive-message \
     --queue-url $(terraform output -raw sqs_notificacao_queue_url) \
     --max-number-of-messages 1
7. Limpeza Preventiva das Filas:
   aws sqs purge-queue --queue-url $(terraform output -raw sqs_processamento_queue_url)
   aws sqs purge-queue --queue-url $(terraform output -raw sqs_notificacao_queue_url)

---

## 5. Testes Realizados e Resultados Obtidos
* **Publicação SNS:** Recebi o `MessageId: 128651b8-1493-53da-8f12-328ee7a30d3b` confirmando o aceite do evento pelo tópico.
* **Consumo na Fila de Processamento:** Obtive a mensagem (`MessageId: fd530ee2-46db-408c-9826-05db205b458d`) com o payload exato puro: `"Body": "{\"evento_tipo\": \"TESTE_FANOUT\", \"status\": \"OK\"}"`.
* **Consumo na Fila de Notificação:** Obtive a cópia paralela da mensagem (`MessageId: 5040b263-e727-49d0-afc6-aa5866146ec8`) com o mesmo payload limpo.
* **Validação do `raw_message_delivery`:** Comprovei que a entrega direta funcionou, pois o corpo recebido não veio encapsulado pelos metadados padrões do SNS (`Type`, `TopicArn`, `Timestamp`, etc.)[cite: 1].
* **Expurgo:** Executei o comando de purge com sucesso em ambas as filas, garantindo filas vazias para as fases subsequentes.

---

## 6. Problemas Encontrados e Soluções Aplicadas
* **Caminho relativo na primeira tentativa de leitura:** Ao tentar rodar `cat infra/terraform/sqs.tf`, o shell acusou arquivo inexistente porque meu terminal já estava posicionado dentro de `infra/terraform`. Ajustei o comando para `cat sqs.tf`, referenciando o diretório de trabalho correto.

---

## 7. Conceitos Aprendidos
* **Padrão Fan-out:** O tópico SNS atua como publicador neutro; cada fila SQS assina o tópico de forma independente, permitindo adicionar novos consumidores no futuro sem alterar o produtor[cite: 1].
* **Regra de Dimensionamento do VisibilityTimeout (6x Lambda Timeout):** Configurado em 60 segundos para uma Lambda de 10 segundos, evitando que a fila reentregue a mensagem a outra instância da função antes do término do processamento e retries internos[cite: 1].
* **Isolamento de Poison Pills com DLQ:** Definição da `redrive_policy` com `maxReceiveCount = 3` e retenção de 14 dias (1.209.600 segundos) para que mensagens com erro recorrente fiquem retidas para análise humana sem travar a esteira[cite: 1].
* **Importância da Queue Policy:** O SNS não entrega mensagens em filas SQS sem permissão explícita baseada em recurso (`aws_sqs_queue_policy`), exigindo vínculo explícito com o ARN de origem (`aws:SourceArn`)[cite: 1].
* **`raw_message_delivery`:** Simplifica o código das funções consumidoras, eliminando a necessidade de fazer duplo `json.loads()` em tempo de execução[cite: 1].