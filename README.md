# ☁️ Nuvem-Privada

Infraestrutura self-hosted para uma nuvem privada pessoal, baseada em **Nextcloud**, orquestrada com **Docker Compose** e acessível remotamente de forma segura através de **Tailscale**. O projeto inclui scripts de automação para provisionamento do servidor, manutenção de rotina e backup a frio dos dados.

---

## 📋 Sobre o Projeto

O **Nuvem-Privada** transforma uma máquina Linux (testado em Pop!_OS/Ubuntu) em um NAS (*Network Attached Storage*) completo, funcionando como uma alternativa auto-hospedada a serviços de nuvem como Google Drive ou Dropbox — com controle total sobre os dados, sem depender de terceiros.

O projeto foi desenhado com três pilares:

- **Praticidade**: um único script (`setup_ambiente.sh`) prepara qualquer máquina "zerada" com tudo o que é necessário para rodar a stack.
- **Resiliência**: rotinas automatizadas de limpeza e manutenção do Nextcloud, evitando acúmulo de lixo no banco de dados e no disco.
- **Segurança dos dados**: backups a frio compactados, acesso remoto via VPN mesh (Tailscale) ao invés de exposição direta na internet, e suporte a volumes criptografados.

---

## 🏗️ Arquitetura

A stack é composta por 4 serviços orquestrados via Docker Compose:

| Serviço | Imagem base | Função |
|---|---|---|
| `app` | `nextcloud:34-apache` + `ffmpeg` (custom) | Aplicação principal do Nextcloud, servida na porta `8080` |
| `db` | `mariadb:10.11` | Banco de dados relacional (isolamento `READ-COMMITTED`, binlog em modo `ROW`) |
| `redis` | `redis:8-alpine` (com senha) | Cache em memória, usado pelo Nextcloud para *file locking* e performance |
| `cron` | mesma imagem de `app` | Executa as tarefas em segundo plano do Nextcloud (`cron.sh`) — notificações, geração de miniaturas, verificações periódicas etc. |

O `ffmpeg` é injetado na imagem via `Dockerfile` customizado para permitir processamento e geração de prévias de arquivos de vídeo diretamente pelo Nextcloud.

`db` e `redis` possuem **health checks** configurados, e `app`/`cron` só sobem depois que ambos reportam estar saudáveis (`depends_on: condition: service_healthy`). Isso evita a condição de corrida da primeira inicialização, em que o Nextcloud tentava conectar no banco antes dele estar pronto para aceitar conexões.

---

## 🛠️ Tecnologias Utilizadas

- **Docker** / **Docker Compose** — containerização e orquestração
- **Nextcloud** — plataforma de nuvem privada
- **MariaDB** — banco de dados
- **Redis** — cache e locking
- **ffmpeg** — processamento de mídia
- **Tailscale** — VPN mesh para acesso remoto seguro, sem expor portas na internet
- **pv** + **xz** — pipeline de backup com barra de progresso e compressão de alta taxa (multi-thread)
- **zulucrypt-cli** — suporte a volumes/discos criptografados

---

## 📁 Estrutura do Projeto

```
Nuvem-Privada/
├── docker-compose.yml      # Definição dos serviços (app, db, redis, cron)
├── Dockerfile               # Imagem Nextcloud + ffmpeg
├── setup_ambiente.sh        # Provisionamento inicial do servidor hospedeiro
├── rotina_nas.sh             # Manutenção periódica (scan de arquivos, limpeza)
├── backup_frio_nas.sh        # Backup a frio compactado (.tar.xz)
├── .env                      # Segredos e caminhos reais (NÃO versionado)
├── .env.example              # Modelo de variáveis (versionado)
├── .gitignore / .dockerignore
├── .github/workflows/lint.yml # CI: shellcheck + validação do compose
├── LICENSE
├── db_data/                  # (gerado em runtime, ignorado no git)
├── redis_data/                # (gerado em runtime, ignorado no git)
├── nextcloud_data/            # (gerado em runtime, ignorado no git)
└── db_dump/                   # (gerado a cada backup, ignorado no git)
```

---

## 🚀 Começando

### Pré-requisitos

- Máquina Linux (o projeto foi construído e testado em **Pop!_OS / Ubuntu**)
- Acesso `sudo`
- Git

### 1. Clonar o repositório

```bash
git clone https://github.com/<seu-usuario>/Nuvem-Privada.git
cd Nuvem-Privada
```

### 2. Provisionar o servidor

O script `setup_ambiente.sh` prepara uma máquina virgem instalando todas as dependências necessárias: Docker, Docker Compose, Docker Buildx, ferramentas de backup (`pv`), criptografia de disco (`zulucrypt-cli`), `ffmpeg` e a VPN **Tailscale**. Ele também adiciona seu usuário ao grupo `docker` e habilita o serviço para iniciar com o sistema.

```bash
chmod +x setup_ambiente.sh
./setup_ambiente.sh
```

> ⚠️ Após a execução, **reinicie a sessão ou o computador** para que a permissão do grupo Docker entre em vigor. Em seguida, rode `sudo tailscale up` para conectar a máquina à sua rede privada.

### 3. Configurar variáveis de ambiente

As credenciais do MariaDB **não ficam mais hardcoded** no `docker-compose.yml` — elas são lidas de um arquivo `.env` local (ignorado pelo git). Copie o modelo e ajuste os valores:

```bash
cp .env.example .env
nano .env   # ou o editor de sua preferência
```

Preencha `MYSQL_ROOT_PASSWORD` e `MYSQL_PASSWORD` com senhas fortes e únicas, e `REDIS_PASSWORD` com uma senha para o Redis (que antes não tinha autenticação nenhuma — agora exige senha via `--requirepass`, e o Nextcloud é informado dela através de `REDIS_HOST_PASSWORD`). O Docker Compose carrega o `.env` automaticamente (por estar no mesmo diretório do `docker-compose.yml`) e substitui as variáveis `${VARIAVEL}` referenciadas no arquivo.

Preencha também `ARQUIVE_PATH` e `BACKUP_PATH` com os caminhos reais dos seus discos/volumes no host. Esses caminhos antes ficavam fixos direto no `docker-compose.yml` (`/mnt/Arquive` e `/mnt/Backup_Cripto`) — agora vivem só no `.env`, que não é versionado. Assim o layout de disco de cada máquina fica fora do repositório e pode ser trocado sem editar o compose.

> ⚠️ **Se você já tem uma instalação rodando** (com dados em `db_data/`), o MariaDB só aplica as senhas do `.env` na **primeira inicialização** do volume. Nesse caso, use no `.env` os **mesmos valores que já estavam em uso** no `docker-compose.yml` antigo — trocar a senha ali não altera a senha já gravada no banco. Para efetivamente rotacionar a senha em uma instalação existente, altere-a via SQL (`ALTER USER` / `SET PASSWORD`) dentro do container `db` e só depois atualize o `.env` para refletir o novo valor.

### 4. Subir a stack

```bash
docker compose up -d --build
```

A aplicação estará disponível em `http://<ip-do-servidor>:8080` (ou pelo IP atribuído pelo Tailscale, para acesso remoto seguro).

---

## 🔐 Segurança e Rede

- O acesso remoto é pensado para ocorrer **via Tailscale**, evitando expor a porta `8080` diretamente na internet.
- O volume `/mnt/Backup` (renomeado a partir do antigo `Backup_Cripto`) é montado com a flag `rshared`, permitindo integração com discos/volumes criptografados gerenciados via `zulucrypt-cli`.
- **Caminhos de disco fora do versionamento**: os caminhos reais de `/mnt/Arquive` e `/mnt/Backup` no host (variáveis `ARQUIVE_PATH` e `BACKUP_PATH`) vivem só no `.env`, e não mais hardcoded no `docker-compose.yml` — assim o layout de disco de cada máquina não vaza para o repositório.
- **Segredos fora do versionamento**: credenciais do banco de dados e do Redis vivem exclusivamente no `.env` (ignorado pelo git e pelo contexto de build do Docker). O `docker-compose.yml` referencia apenas `${VARIAVEL}`, e o `.env.example` documenta quais variáveis existem sem expor valores reais.
- Nunca faça commit do arquivo `.env`. Se ele já foi versionado por engano em algum momento, além de removê-lo do histórico do git, troque as senhas imediatamente — elas devem ser consideradas comprometidas.
- **Redis com autenticação**: antes o Redis aceitava qualquer conexão dentro da rede interna do Compose, sem senha. Agora exige `REDIS_PASSWORD` (via `--requirepass`), reduzindo a superfície caso outro container comprometido tente acessá-lo.
- **Imagens fixadas em versão estável**: `nextcloud:latest` e `redis:alpine` foram trocados por `nextcloud:34-apache` e `redis:8-alpine` — as majors estáveis mais recentes de cada projeto no momento desta escrita. Isso evita saltos de major version não intencionais (o Nextcloud não suporta pular majors em upgrade) enquanto ainda recebe patches dentro da mesma série. Veja a seção **"Atualizando Versões"** abaixo para saber como fazer o bump deliberadamente.

---

## 🧰 Scripts de Automação

### `setup_ambiente.sh`
Prepara o servidor hospedeiro do zero: instala Docker e suas extensões, ferramentas de linha de comando (`pv`, `git`, `curl`), `zulucrypt-cli`, `ffmpeg` e o cliente Tailscale, além de configurar permissões e serviços do sistema.

### `rotina_nas.sh`
Script de manutenção periódica do Nextcloud, pensado para ser agendado via `cron`. Executa:
1. **`files:scan --all`** — sincroniza o índice do Nextcloud com os arquivos físicos em disco;
2. **`trashbin:cleanup --all-users`** — limpa lixeiras expiradas de todos os usuários;
3. **`versions:cleanup`** — remove versões antigas de arquivos, liberando espaço.

Exemplo de agendamento diário às 3h da manhã:
```bash
crontab -e
# adicionar a linha:
0 3 * * * /home/canela/git/Nuvem-Privada/rotina_nas.sh >> /var/log/nas_rotina.log 2>&1
```

### `backup_frio_nas.sh`
Realiza um **backup a frio** (com os serviços temporariamente desligados, garantindo consistência do banco de dados). O destino do backup (`$ARQUIVE_PATH/Backup-NAS`) é lido diretamente do `.env` do projeto (variável `ARQUIVE_PATH`), então basta apontar essa variável para o disco correto de cada máquina:
1. Gera um **dump lógico** do MariaDB (`mariadb-dump --all-databases`) ainda com os containers no ar — complementa o backup físico do volume, sendo mais portável entre versões do banco e mais fácil de inspecionar/restaurar isoladamente;
2. Executa `docker compose down` para parar a stack;
3. Calcula o volume total de dados a compactar;
4. Compacta todo o diretório do projeto (incluindo o dump gerado no passo 1) com `tar` + `pv` (barra de progresso) + `xz -9 -T0` (compressão máxima, multi-thread, limite de 7 GiB de memória);
5. **Verifica a integridade** do arquivo `.tar.xz` gerado (`xz -t`) antes de considerar o backup válido — se a verificação falhar, o script religa os containers e aborta com erro;
6. Religa a stack com `docker compose up -d` e **remove backups com mais de 30 dias** (`RETENCAO_DIAS`, editável no topo do script) para o disco não encher indefinidamente.

```bash
chmod +x backup_frio_nas.sh
./backup_frio_nas.sh
```

> 💡 Por parar os containers durante a compactação, este script é ideal para ser agendado em horários de baixo uso (madrugada), garantindo um backup íntegro e consistente do banco de dados.

#### Testando a restauração

Um backup nunca testado não é uma garantia. Periodicamente vale validar que ele realmente restaura:

> O caminho `/mnt/Arquive` abaixo é o valor padrão sugerido no `.env.example`; ajuste para o valor de `ARQUIVE_PATH` definido no seu `.env` real, se for diferente.

```bash
# Extrair um backup específico em uma pasta separada, sem sobrescrever o ambiente atual
mkdir -p /tmp/teste_restauracao
tar -xf /mnt/Arquive/Backup-NAS/backup_nuvem_<timestamp>.tar.xz -C /tmp/teste_restauracao

# Testar o dump lógico isoladamente, sem tocar no ambiente de produção
gunzip -c /tmp/teste_restauracao/db_dump/dump_latest.sql.gz | head -n 20
```

---

## 🔄 Atualizando Versões

As imagens de `app`/`cron` (Nextcloud) e `redis` estão fixadas em uma major específica (`34-apache` e `8-alpine`) em vez de `latest`, então elas **não sobem sozinhas** quando uma nova major é lançada — isso é intencional, já que o Nextcloud não permite pular majors em upgrade (ex: ir direto de 34 para 36 pode quebrar a instância).

Para atualizar deliberadamente:

1. Confira no [Docker Hub do Nextcloud](https://hub.docker.com/_/nextcloud) qual é a tag estável mais recente;
2. Atualize a tag no `Dockerfile` (ex: de `nextcloud:34-apache` para `nextcloud:35-apache`);
3. Rode `docker compose build --pull && docker compose up -d`;
4. Acesse a interface web do Nextcloud — o próprio sistema conduz a migração do banco de dados quando detecta uma nova major version.

> ⚠️ Sempre faça um backup (`./backup_frio_nas.sh`) **antes** de qualquer upgrade de major version — migrações de schema não são reversíveis.

## 🧪 Integração Contínua

O workflow `.github/workflows/lint.yml` roda automaticamente em cada `push`/`pull request` para a branch `main`:
- **ShellCheck** nos scripts `.sh`, pegando problemas de quoting, variáveis não usadas etc.;
- **`docker compose config`**, validando que o `docker-compose.yml` está sintaticamente correto (usando o `.env.example` como stand-in, já que segredos reais não existem no ambiente de CI).

---

## 💾 Persistência de Dados

Os seguintes diretórios são gerados em runtime e **não são versionados** (ver `.gitignore`/`.dockerignore`):

- `db_data/` — dados do MariaDB
- `redis_data/` — cache do Redis
- `nextcloud_data/` — arquivos de aplicação e dados dos usuários do Nextcloud
- `db_dump/` — dump lógico mais recente do banco (`dump_latest.sql.gz`), regravado a cada execução de `backup_frio_nas.sh`

Volumes externos montados no container `app` (caminhos reais definidos no `.env`, veja `ARQUIVE_PATH` e `BACKUP_PATH`):
- `/mnt/Arquive` — armazenamento de arquivos/backups de longo prazo
- `/mnt/Backup` — volume criptografado para backups sensíveis (antigo `Backup_Cripto`)

---

## 📄 Licença

Este projeto está licenciado sob a licença **MIT** — veja o arquivo [LICENSE](./LICENSE) para mais detalhes.

Copyright (c) 2026 Gabriel Canela