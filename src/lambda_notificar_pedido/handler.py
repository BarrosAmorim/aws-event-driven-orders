import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(os.getenv("LOG_LEVEL", "INFO"))


def extrair_corpo_evento(record_body: str) -> dict:
    """Extrai os dados de negócio considerando o envelope do SNS ou entrega direta."""
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
