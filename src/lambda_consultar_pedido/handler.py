import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(os.getenv("LOG_LEVEL", "INFO"))


def lambda_handler(event, context):
    logger.info("Consulta de pedido iniciada.")
    return {
        "statusCode": 200,
        "body": json.dumps({"mensagem": "Endpoint de consulta em implementacao."}),
    }
