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
| `app` | `nextcloud:latest` + `ffmpeg` (custom) | Aplicação principal do Nextcloud, servida na porta `8080` |
| `db` | `mariadb:10.11` | Banco de dados relacional (isolamento `READ-COMMITTED`, binlog em modo `ROW`) |
| `redis` | `redis:alpine` | Cache em memória, usado pelo Nextcloud para *file locking* e performance |
| `cron` | mesma imagem de `app` | Executa as tarefas em segundo plano do Nextcloud (`cron.sh`) — notificações, geração de miniaturas, verificações periódicas etc. |

O `ffmpeg` é injetado na imagem via `Dockerfile` customizado para permitir processamento e geração de prévias de arquivos de vídeo diretamente pelo Nextcloud.

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
├── .gitignore / .dockerignore
├── LICENSE
├── db_data/                  # (gerado em runtime, ignorado no git)
├── redis_data/                # (gerado em runtime, ignorado no git)
└── nextcloud_data/            # (gerado em runtime, ignorado no git)
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

### 3. Configurar variáveis sensíveis

O `docker-compose.yml` atual contém credenciais de exemplo do MariaDB diretamente no arquivo. **Antes de subir a stack**, é altamente recomendado:

- Trocar as senhas padrão (`MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`) por valores fortes e únicos;
- Mover essas variáveis para um arquivo `.env` (não versionado) e referenciá-las no `docker-compose.yml` com `${VARIAVEL}`, evitando que segredos fiquem expostos no controle de versão.

### 4. Subir a stack

```bash
docker compose up -d --build
```

A aplicação estará disponível em `http://<ip-do-servidor>:8080` (ou pelo IP atribuído pelo Tailscale, para acesso remoto seguro).

---

## 🔐 Segurança e Rede

- O acesso remoto é pensado para ocorrer **via Tailscale**, evitando expor a porta `8080` diretamente na internet.
- O volume `/mnt/Backup_Cripto` é montado com a flag `rshared`, permitindo integração com discos/volumes criptografados gerenciados via `zulucrypt-cli`.
- Recomenda-se revisar e reforçar as credenciais do banco de dados antes do primeiro uso em produção, conforme descrito acima.

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
Realiza um **backup a frio** (com os serviços temporariamente desligados, garantindo consistência do banco de dados):
1. Executa `docker compose down` para parar a stack;
2. Calcula o volume total de dados a compactar;
3. Compacta todo o diretório do projeto com `tar` + `pv` (barra de progresso) + `xz -9 -T0` (compressão máxima, multi-thread, limite de 7 GiB de memória);
4. Salva o arquivo resultante em `/mnt/Arquive/Backup-NAS/backup_nuvem_<timestamp>.tar.xz`;
5. Religa a stack com `docker compose up -d`.

```bash
chmod +x backup_frio_nas.sh
./backup_frio_nas.sh
```

> 💡 Por parar os containers durante a compactação, este script é ideal para ser agendado em horários de baixo uso (madrugada), garantindo um backup íntegro e consistente do banco de dados.

---

## 💾 Persistência de Dados

Os seguintes diretórios são gerados em runtime e **não são versionados** (ver `.gitignore`/`.dockerignore`):

- `db_data/` — dados do MariaDB
- `redis_data/` — cache do Redis
- `nextcloud_data/` — arquivos de aplicação e dados dos usuários do Nextcloud

Volumes externos montados no container `app`:
- `/mnt/Arquive` — armazenamento de arquivos/backups de longo prazo
- `/mnt/Backup_Cripto` — volume criptografado para backups sensíveis

---

## 📄 Licença

Este projeto está licenciado sob a licença **MIT** — veja o arquivo [LICENSE](./LICENSE) para mais detalhes.

Copyright (c) 2026 Gabriel Canela