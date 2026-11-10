import json
import logging
import os
from decimal import Decimal

# Configuração do logger estruturado
logger = logging.getLogger()
logger.setLevel(os.getenv("LOG_LEVEL", "INFO"))


class DecimalEncoder(json.JSONEncoder):
    """Permite serializar objetos Decimal retornados pelo DynamoDB para float/int."""

    def default(self, obj):
        if isinstance(obj, Decimal):
            if obj % 1 == 0:
                return int(obj)
            return float(obj)
        return super().default(obj)


def format_response(status_code: int, body: dict) -> dict:
    """Padroniza o payload de retorno para o API Gateway."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body, cls=DecimalEncoder),
    }
