# Desafio Técnico – Solução DevOps para Aplicação PHP (WordPress)

Este repositório contém a solução completa para o Desafio Técnico de Analista DevOps. O objetivo foi modernizar o ciclo de vida de uma aplicação PHP legada, usando o WordPress como um caso de estudo realista. A solução abrange desde a containerização segura até o provisionamento de uma infraestrutura resiliente e automatizada na AWS com Terraform, culminando em uma estratégia de observabilidade para produção.

## 1\. Visão Geral da Solução

O projeto cria uma fundação sólida para a aplicação, focando em automação, segurança e escalabilidade. As seguintes tecnologias e práticas foram utilizadas:

* **Containerização:** Docker, para empacotar a aplicação WordPress e suas dependências de forma isolada e portátil.
* **Integração Contínua (CI):** GitHub Actions, para automatizar o build, análise de vulnerabilidades e publicação da imagem Docker.
* **Infraestrutura como Código (IaC):** Terraform, para provisionar e gerenciar toda a infraestrutura na AWS de forma declarativa e reprodutível.
* **Nuvem (Cloud):** AWS, utilizando uma arquitetura serverless e gerenciada com ECS Fargate, RDS, EFS, ALB e Secrets Manager para minimizar a carga operacional.

## 2\. Arquitetura Visual da Solução

O diagrama abaixo ilustra a topologia completa da infraestrutura provisionada na AWS e o fluxo de CI/CD.

![Diagrama da Arquitetura](./arquitetura_da_aplicação_wordpress_na_aws.png)

### Fluxo de Implantação (CI/CD)

1. **Código e Trigger:** Um desenvolvedor envia código (`git push`) para o repositório no **GitHub**.
2. **Pipeline:** O push aciona o workflow do **GitHub Actions**.
3. **Build e Push:** O pipeline constrói a imagem Docker, a escaneia e a envia para um registro de contêineres (**Docker Hub**).
4. **Deploy:** Ao executar `terraform apply`, a **Definição de Tarefa do ECS** é atualizada para usar a nova tag da imagem. O ECS então inicia uma nova tarefa puxando a imagem mais recente do registro. Essa comunicação de saída da sub-rede privada para o Docker Hub é possível graças ao **NAT Gateway**.

### Fluxo de Tráfego do Usuário (Runtime)

1. **Requisição Inicial:** O usuário acessa a URL. A requisição chega ao **Internet Gateway (IGW)** e é direcionada ao **Application Load Balancer (ALB)**, que reside nas **sub-redes públicas**.
2. **Balanceamento de Carga:** O ALB encaminha a requisição para uma tarefa do **Serviço ECS** na porta `8080`. A comunicação é controlada por Security Groups.
3. **Execução da Aplicação:** A tarefa ECS, rodando na **sub-rede privada**, processa a requisição.
      * **Segredos:** A tarefa busca as credenciais do banco de dados no **AWS Secrets Manager**.
      * **Banco de Dados:** Conecta-se à instância **RDS** para buscar e salvar dados.
      * **Arquivos:** Acessa o sistema de arquivos **EFS** para carregar e salvar uploads, temas e plugins (No caso de wordpress, é necessário persistir essas pastas de arquivos).
4. **Resposta:** A página gerada faz o caminho de volta (ECS -\> ALB -\> IGW -\> Usuário).

## 3\. Etapa 1: Containerização (Dockerfile)

**Arquivo:** `Dockerfile`

O primeiro passo foi containerizar a aplicação WordPress. O `Dockerfile` foi projetado com foco em segurança e otimização.

### Decisões Técnicas

* **Imagem Base:** Utilizamos a imagem oficial `php:8.2-apache`, que é uma base robusta, segura e mantida pela comunidade.
* **Segurança (Usuário Não-Root):** Para mitigar o impacto de possíveis vulnerabilidades, o contêiner executa o processo do Apache com o usuário de baixo privilégio `www-data`.
* **Porta Não Privilegiada (8080):** Como o contêiner roda com um usuário não-root, ele não tem permissão para usar portas abaixo de 1024. O Apache foi reconfigurado para escutar na porta `8080`, evitando o erro `Permission Denied` na inicialização e seguindo a prática de "menor privilégio".

## 4\. Etapa 2: Integração Contínua (CI com GitHub Actions)

**Arquivo:** `.github/workflows/main.yml`

Um pipeline de CI foi criado para automatizar a construção, validação e publicação da nossa imagem Docker customizada.

### Fluxo do Pipeline

1. **Gatilho (Trigger):** O pipeline é acionado a cada `push` na branch `main`.
2. **Autenticação:** Realiza o login de forma segura no Docker Hub utilizando `secrets` do GitHub.
3. **Build da Imagem:** Constrói a imagem Docker a partir do nosso `Dockerfile`.
4. **Análise de Vulnerabilidades:** Utiliza a ferramenta **Trivy** para escanear a imagem em busca de vulnerabilidades conhecidas (CVEs). O pipeline é configurado para falhar se vulnerabilidades de nível `HIGH` ou `CRITICAL` forem encontradas, funcionando como um portão de qualidade de segurança.
5. **Push da Imagem:** Se a análise for bem-sucedida, a imagem validada é enviada para o Docker Hub, com uma tag correspondente à branch (`main`), garantindo rastreabilidade.

## 5\. Etapa 3: Infraestrutura como Código (IaC com Terraform)

**Arquivos:** `terraform/*.tf`

Toda a infraestrutura na AWS é gerenciada de forma declarativa com o Terraform.

### Justificativa da Arquitetura: ECS com Fargate

Optei por usar **AWS ECS com Fargate** em vez de EKS (Kubernetes). Para a necessidade do projeto (uma aplicação monolítica como o WordPress), Fargate oferece a melhor combinação de simplicidade operacional, custo-benefício e integração com o ecossistema AWS. Sendo uma plataforma *serverless*, ela elimina a necessidade de gerenciar a infraestrutura de nós (servidores), permitindo que a equipe foque na aplicação.

## 6\. Etapa 4: Estratégia de Observabilidade

Para monitorar esta aplicação em produção, a stack de ferramentas escolhida seria a **PLG Stack (Prometheus, Loki e Grafana)**, preferencialmente utilizando os serviços gerenciados da AWS (Amazon Managed Service for Prometheus e Amazon Managed Grafana).

* **Justificativa:** Esta stack é o padrão de mercado para observabilidade em ambientes cloud-native, oferecendo ferramentas poderosas e especializadas para métricas, logs e visualização em dashboards.

### 3 Principais Métricas para o Dashboard de Saúde

1. **Golden Signals do Tráfego (via ALB):**
      * **Latência:** Tempo médio de resposta das requisições (mede a experiência do usuário).
      * **Taxa de Erros:** Contagem de respostas HTTP 5xx (mede a saúde da aplicação).
      * **Throughput:** Número de requisições por segundo (mede a carga na aplicação).
2. **Saúde da Computação (via ECS/Fargate):**
      * **Utilização de CPU e Memória:** Percentual de uso dos recursos alocados para os contêineres. Essencial para configurar auto-scaling e prever custos.
3. **Saúde do Banco de Dados (via RDS):**
      * **Utilização de CPU e Conexões Abertas:** Monitorar a carga no banco de dados, que é um gargalo comum em aplicações WordPress.

## 7\. Como Executar a Solução

### Pré-requisitos

* [Docker](https://www.docker.com/)
* [Terraform](https://www.terraform.io/)
* [AWS CLI](https://aws.amazon.com/cli/) configurada com credenciais (`aws configure`)

#### Passos

1. **Clone este repositório:**

      ```bash
      git clone https://github.com/Anderson-J/devops-wp.git
      cd devops-wp
      ```

2. **Navegue para a pasta do Terraform:**

    ```bash
    cd terraform
    ```

3. **Inicialize o Terraform:**

    ```bash
    terraform init
    ```

4. **Crie a infraestrutura:**

    ```bash
    terraform apply
    ```

      * Revise o plano e digite `yes` para confirmar.
      * Aguarde alguns minutos para que todos os recursos (VPC, RDS, ECS, etc.) sejam provisionados.

5. **Acesse o site:**
      * Ao final, o Terraform exibirá os outputs. Copie o valor de `URL_do_Site_WordPress` e cole no seu navegador para iniciar a instalação do WordPress.

## 8\. Como Destruir a Infraestrutura

Para remover todos os recursos criados na AWS navegue até a pasta `terraform` e execute:

```bash
terraform destroy
```

* Revise os recursos a serem destruídos e digite `yes` para confirmar.
