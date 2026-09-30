# Registo da Etapa 2: Base do Terraform e Armazenamento (DynamoDB)

## 1. Objetivo e Problema que Resolve
Nesta etapa, estruturei a base de Infraestrutura como Código (IaC) com Terraform e provisionei a camada de persistência de dados do sistema no Amazon DynamoDB[cite: 1]. O objetivo foi estabelecer um modelo de gestão de estado remoto seguro com bloqueio nativo de concorrência e disponibilizar a tabela NoSQL onde os pedidos serão persistidos de forma atómica e com chave de idempotência[cite: 1].

## 2. O que Foi Criado / Recursos Envolvidos
* **Bucket S3 para Backend Remoto:** `terraform-state-rafael-pedidos-event-driven` provisionado na região `us-east-1`, com versionamento ativo para proteção contra corrupção do ficheiro de estado e bloqueio público rigoroso (*Public Access Block*).
* **Configuração de Backend Remoto:** `infra/terraform/backend.tf` configurado com `use_lockfile = true`, dispensando a criação e o custo de uma tabela DynamoDB auxiliar para controlo de concorrência[cite: 1].
* **Provedor e Variáveis do Terraform:** `variables.tf` e `main.tf` parametrizados com variáveis de entrada e *default tags* globais[cite: 1].
* **Tabela Amazon DynamoDB:** `infra/terraform/dynamodb.tf` declarando a tabela `pedidos-event-driven-pedidos-dev` com modelo sob procura `PAY_PER_REQUEST` e Partition Key `pedido_id`[cite: 1].
* **Outputs do Terraform:** `infra/terraform/outputs.tf` exportando o nome e o ARN da tabela para reutilização nas próximas etapas[cite: 1].

## 3. Configurações Implementadas nos Ficheiros `.tf`

### A. `infra/terraform/variables.tf`
Defini as variáveis estruturais para eliminar valores fixos (*hardcoded*) e permitir parametrização por ambiente[cite: 1]:
```hcl
variable "aws_region" {
  description = "Região da AWS onde os recursos serão provisionados"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome base do projeto para prefixo de recursos"
  type        = string
  default     = "pedidos-event-driven"
}

variable "environment" {
  description = "Ambiente de implantação (dev, staging, prod)"
  type        = string
  default     = "dev"
}
```

### B. `infra/terraform/main.tf`
Defini a versão mínima do Terraform (`>= 1.10.0`) necessária para o suporte nativo a `use_lockfile`, a versão do provedor AWS (`~> 5.0`) e as etiquetas padrão aplicadas a todos os recursos geridos[cite: 1]:
```hcl
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
```

### C. `infra/terraform/backend.tf`
Configurei o armazenamento remoto do estado no Amazon S3 com a validação nativa de lock[cite: 1]:
```hcl
terraform {
  backend "s3" {
    bucket       = "terraform-state-rafael-pedidos-event-driven"
    key          = "pedidos-event-driven/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
```

### D. `infra/terraform/dynamodb.tf`
Declarei a tabela de pedidos respeitando a modelagem NoSQL *schemaless* (apenas a chave primária declarada no IaC) e a cobrança por consumo real[cite: 1]:
```hcl
resource "aws_dynamodb_table" "pedidos" {
  name         = "${var.project_name}-pedidos-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pedido_id"

  attribute {
    name = "pedido_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = false
  }

  tags = {
    Name = "${var.project_name}-pedidos-${var.environment}"
  }
}
```

### E. `infra/terraform/outputs.tf`
Exportei os identificadores essenciais para alimentar as políticas de privilégio mínimo no IAM e as variáveis de ambiente das funções Lambda nas etapas seguintes[cite: 1]:
```hcl
output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB de pedidos"
  value       = aws_dynamodb_table.pedidos.name
}

output "dynamodb_table_arn" {
  description = "ARN da tabela DynamoDB de pedidos"
  value       = aws_dynamodb_table.pedidos.arn
}
```

## 4. Comandos Executados e Locais de Execução
Todos os comandos foram executados diretamente no meu terminal Linux:

1. **Preenchimento dos ficheiros Terraform:**
   * *Local:* Pasta raiz do projeto (`aws-event-driven-orders/`) e pasta `infra/terraform/`[cite: 1].
2. **Verificação de estilo e formatação:**
   * *Local:* `infra/terraform/`[cite: 1]
   * *Comando:* `cd infra/terraform && terraform fmt -check`
3. **Criação e proteção do bucket S3 de backend (Bootstrap):**
   * *Local:* `infra/terraform/`[cite: 1]
   * *Comandos:*
     * `aws s3api create-bucket --bucket terraform-state-rafael-pedidos-event-driven --region us-east-1`
     * `aws s3api put-bucket-versioning --bucket terraform-state-rafael-pedidos-event-driven --versioning-configuration Status=Enabled`
     * `aws s3api put-public-access-block --bucket terraform-state-rafael-pedidos-event-driven --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"`
4. **Inicialização do Terraform com backend remoto:**
   * *Local:* `infra/terraform/`[cite: 1]
   * *Comando:* `terraform init`
5. **Validação estrutural e sintática:**
   * *Local:* `infra/terraform/`[cite: 1]
   * *Comando:* `terraform validate`
6. **Planeamento da infraestrutura:**
   * *Local:* `infra/terraform/`[cite: 1]
   * *Comando:* `terraform plan`
7. **Aplicação e aprovação na AWS:**
   * *Local:* `infra/terraform/`[cite: 1]
   * *Comando:* `terraform apply`

## 5. Testes Realizados e Resultados Obtidos
* **Formatação (`terraform fmt -check`):** Validou que todos os ficheiros criados respeitam as convenções oficiais de indentação e alinhamento da HashiCorp.
* **Validação Sintática (`terraform validate`):** Confirmou a integridade das referências cruzadas entre recursos, variáveis e saídas (`Success! The configuration is valid.`)[cite: 1].
* **Plano de Execução (`terraform plan`):** Mapeou com exatidão a adição de 1 recurso (`aws_dynamodb_table.pedidos`), o cálculo dos 2 outputs e 0 alterações/destruições[cite: 1].
* **Provisionamento (`terraform apply`):** A AWS provisionou a tabela DynamoDB em 15 segundos e gravou o estado de forma encriptada e remota no bucket S3[cite: 1].

## 6. Problemas Encontrados e Soluções Aplicadas
* **Problema Encontrado:** Ao rodar `terraform validate`, o terminal retornou o erro `Reference to undeclared resource` indicando que o recurso `aws_dynamodb_table.pedidos` referenciado no `outputs.tf` não existia no módulo raiz[cite: 1].
* **Diagnóstico:** Executei `cat dynamodb.tf` e verifiquei que o ficheiro se encontrava com 0 bytes porque o redirecionamento anterior havia falhado ou sido omitido[cite: 1].
* **Solução Aplicada:** Escrevi a declaração do recurso diretamente no ficheiro `infra/terraform/dynamodb.tf` com o comando `cat << 'EOF' > dynamodb.tf` e repeti o comando de validação, obtendo sucesso imediato[cite: 1].

## 7. Conceitos Aprendidos
* **Dilema do Bootstrap ("Ovo e a Galinha"):** Entendi que o bucket que armazena o ficheiro de estado não deve ser gerido dentro do mesmo módulo Terraform que depende dele, evitando dependências circulares e riscos de autodestruição do estado.
* **Bloqueio Nativo com `use_lockfile`:** Compreendi a evolução do Terraform v1.10, que utiliza chamadas condicionais nativas da API do Amazon S3 (`PutObject`) para bloquear execuções simultâneas, dispensando o recurso extra de uma tabela DynamoDB de locking[cite: 1].
* **Modelagem NoSQL Schemaless:** Fixei que tabelas DynamoDB não exigem declaração prévia de colunas no Terraform; declaramos no IaC apenas os atributos da chave primária (`pedido_id`), enquanto atributos adicionais (`status`, `itens`, `cliente_id`) são manipulados dinamicamente pela aplicação[cite: 1].
* **Otimização de Custos (FinOps):** Verifiquei que o modo `PAY_PER_REQUEST` é a escolha ideal para arquiteturas serverless em desenvolvimento, pois não cobra tarifa por hora parada, faturando estritamente pelo número de leituras e escritas realizadas[cite: 1].

## 8. Evidências Coletadas

### Criação do Bucket S3 de Estado
```json
{
    "Location": "/terraform-state-rafael-pedidos-event-driven"
}
```

### Inicialização do Terraform (`terraform init`)
```text
Initializing the backend...
Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.100.0...
- Installed hashicorp/aws v5.100.0 (signed by HashiCorp)

Terraform has been successfully initialized!
```

### Plano de Execução (`terraform plan`)
```text
Plan: 1 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + dynamodb_table_arn  = (known after apply)
  + dynamodb_table_name = "pedidos-event-driven-pedidos-dev"
```

### Execução do Apply (`terraform apply`)
```text
aws_dynamodb_table.pedidos: Creation complete after 15s [id=pedidos-event-driven-pedidos-dev]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

dynamodb_table_arn = "arn:aws:dynamodb:us-east-1:696537703431:table/pedidos-event-driven-pedidos-dev"
dynamodb_table_name = "pedidos-event-driven-pedidos-dev"
```