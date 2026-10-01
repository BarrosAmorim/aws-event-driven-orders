# Registro da Etapa 4: Segurança e Acessos (IAM)

## 1. Objetivo e Problema que Resolve
Eu estruturei a camada de segurança e permissões de execução (*Execution Roles*) para as quatro funções AWS Lambda da arquitetura orientada a eventos. O objetivo central foi implementar rigorosamente o princípio do menor privilégio (*Least Privilege*), garantindo que cada função tenha apenas os acessos mínimos e indispensáveis para realizar suas operações, eliminando permissões amplas ou compartilhamento de papéis entre diferentes domínios da aplicação.

---

## 2. Recursos Envolvidos e Código Terraform Declarado
Eu criei e configurei o arquivo `infra/terraform/iam.tf` contendo a política de confiança compartilhada, as 4 roles e suas respectivas políticas de acesso inline e gerenciadas.

```hcl
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
```

---

## 3. Passo a Passo da Execução

Todos os comandos foram executados no diretório de infraestrutura:
`~/projects/aws-event-driven-orders/infra/terraform`

### Passo 1: Criação da Trust Policy
Eu iniciei o arquivo `iam.tf` definindo a política de confiança básica para o serviço AWS Lambda:
```bash
cat << 'EOF' > iam.tf
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
EOF
```

### Passo 2: Declaração da Role e Políticas da `lambda_criar_pedido`
Eu adicionei ao arquivo a role da primeira função com permissões para CloudWatch Logs, `PutItem`/`GetItem` no DynamoDB e `Publish` no tópico SNS:
```bash
cat << 'EOF' >> iam.tf

resource "aws_iam_role" "lambda_criar_pedido" {
  name               = "role-lambda-criar-pedido"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_criar_pedido_logs" {
  role       = aws_iam_role.lambda_criar_pedido.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

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
EOF
```

### Passo 3: Declaração da Role e Políticas da `lambda_consultar_pedido`
Eu inseri a role da função de consulta contendo unicamente permissão de leitura (`GetItem`) na tabela de pedidos:
```bash
cat << 'EOF' >> iam.tf

resource "aws_iam_role" "lambda_consultar_pedido" {
  name               = "role-lambda-consultar-pedido"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_consultar_pedido_logs" {
  role       = aws_iam_role.lambda_consultar_pedido.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

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
EOF
```

### Passo 4: Declaração da Role e Políticas da `lambda_processar_pedido`
Eu configurei a role da função de processamento com permissões para ler e excluir mensagens da fila SQS (`sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:GetQueueAttributes`) e atualizar o pedido no DynamoDB (`dynamodb:UpdateItem`):
```bash
cat << 'EOF' >> iam.tf

resource "aws_iam_role" "lambda_processar_pedido" {
  name               = "role-lambda-processar-pedido"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_processar_pedido_logs" {
  role       = aws_iam_role.lambda_processar_pedido.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

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
EOF
```

### Passo 5: Declaração da Role e Políticas da `lambda_notificar_pedido`
Eu adicionei a role do consumidor de notificações, limitando o acesso estritamente ao consumo da fila SQS de notificação:
```bash
cat << 'EOF' >> iam.tf

resource "aws_iam_role" "lambda_notificar_pedido" {
  name               = "role-lambda-notificar-pedido"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_notificar_pedido_logs" {
  role       = aws_iam_role.lambda_notificar_pedido.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

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
EOF
```

### Passo 6: Formatação e Validação Sintática
Eu executei a formatação canônica e a validação do Terraform:
```bash
terraform fmt && terraform validate
```

### Passo 7: Correção de Referência do Tópico SNS
Durante a validação, identifiquei uma divergência na referência ao tópico SNS (`aws_sns_topic.pedidos` vs `aws_sns_topic.pedidos_topico`). Realizei a correção direta via `sed` e revalidei:
```bash
sed -i 's/aws_sns_topic.pedidos.arn/aws_sns_topic.pedidos_topico.arn/g' iam.tf
terraform fmt && terraform validate
```
*Resultado:* `Success! The configuration is valid.`

### Passo 8: Planejamento da Infraestrutura
Eu processei o plano de execução para inspecionar os recursos antes da aplicação:
```bash
terraform plan
```
*Resultado:* `Plan: 21 to add, 0 to change, 0 to destroy.`

### Passo 9: Aplicação na AWS
Eu executei o provisionamento real dos recursos:
```bash
terraform apply
```
*Resultado:* `Apply complete! Resources: 21 added, 0 changed, 0 destroyed.`

### Passo 10: Auditoria e Validação via AWS CLI
Eu executei uma consulta com o AWS CLI para comprovar a existência e integridade das 4 roles criadas no IAM:
```bash
aws iam list-roles --query "Roles[?contains(RoleName, 'role-lambda-')].RoleName" --output table
```

---

## 4. Testes Realizados e Resultados Obtidos
1. **Validação Sintática do Terraform:**
   * O compilador validou todas as referências cruzadas (`Success! The configuration is valid.`).
2. **Execução do Plano e Aplicação:**
   * Os 21 recursos declarados (englobando as etapas de DynamoDB, SNS, SQS e IAM) foram provisionados sem conflitos.
3. **Auditoria no IAM via AWS CLI:**
   * Saída confirmada da consulta de roles:
     ```text
     ----------------------------------
     |            ListRoles           |
     +--------------------------------+
     |  role-lambda-consultar-pedido  |
     |  role-lambda-criar-pedido      |
     |  role-lambda-notificar-pedido  |
     |  role-lambda-processar-pedido  |
     +--------------------------------+
     ```

---

## 5. Problemas Encontrados e Soluções Aplicadas
* **Caminho relativo inicial:** Ao executar o comando apontando para `infra/terraform/iam.tf`, o shell retornou `No such file or directory` porque a sessão do terminal já se encontrava dentro do subdiretório `infra/terraform`. Ajustei os comandos para referenciar diretamente `iam.tf`.
* **Referência a recurso não declarado:** O `terraform validate` acusou erro na linha 51 apontando que `aws_sns_topic.pedidos` não existia. Eu inspecionei o arquivo `sns.tf`, constatei que o nome lógico adotado na etapa anterior foi `aws_sns_topic.pedidos_topico` e corrigi a interpolação em `iam.tf` usando o `sed`.

---

## 6. Conceitos Aprendidos
* **Trust Policy (AssumeRolePolicy) vs. Identity Policy:** A Trust Policy define a fronteira de segurança sobre quem pode assumir a identidade (restringindo exclusivamente ao serviço `lambda.amazonaws.com`), impedindo que usuários humanos, containers ou outras contas executem `sts:AssumeRole`. Já as Identity Policies definem as ações exatas que essa identidade pode executar nos recursos da AWS.
* **Isolamento de Responsabilidades e Menor Privilégio:** Ao invés de uma role compartilhada genérica, manter quatro papéis distintos garante que a função de consulta não tenha como apagar itens ou enviar mensagens, que o notificador não toque no banco de dados, e que o criador de pedidos só publique no SNS e grave pendências.
* **Relação entre Event Source Mapping e IAM:** Funções Lambda acionadas por SQS precisam obrigatoriamente de permissões de leitura e deleção (`sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:GetQueueAttributes`) para que o serviço interno de polling da AWS consiga consumir e retirar mensagens da fila após o processamento.