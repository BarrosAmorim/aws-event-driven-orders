Documento de Arquitetura Consolidado: Sistema de Processamento de Pedidos — AWS Event-Driven
1. Visão Geral da Arquitetura e Decisões Técnicas
A solução adota uma arquitetura orientada a eventos (event-driven) e sem servidor (serverless) na AWS, desacoplando o recebimento de pedidos da execução das regras de negócio e das comunicações ao cliente.


[Cliente HTTP]
│
▼
[Amazon API Gateway]
│
├─── POST /pedidos ──────────────► [Lambda: Criar Pedido]
│                                         │
│                                         ├──► [DynamoDB: Grava PENDING (Escrita Condicional)]
│                                         │
│                                         └──► [Amazon SNS: Tópico Pedidos]
│                                                      │
│                                  ┌───────────────────┴───────────────────┐
│                                  ▼                                       ▼
│                       [SQS: Fila Processamento]               [SQS: Fila Notificação]
│                                  │                                       │
│                                  ▼                                       ▼
│                     [Lambda: Processar Pedido]              [Lambda: Notificar Pedido]
│                                  │                                       │
│                         ┌────────┴────────┐                              ▼
│                         ▼                 ▼                     [Simulação de Envio /
│                    [Sucesso]        [Falha x3 retries]              Logs CloudWatch]
│                         │                 │
│                         ▼                 ▼
│               [DynamoDB: Status      [SQS: DLQ]
│                  COMPLETED]
│
└─── GET /pedidos/{id} ──────────► [Lambda: Consultar Pedido]
│
└──► [DynamoDB: Leitura direta por PK]
