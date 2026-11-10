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
    """Extrai os dados de negócio considerando o envelope do SNS ou entrega direta."""
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

            # Simulação de erro controlado para validação de retries e DLQ (Etapa 9)
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
