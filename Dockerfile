# Fixado na major mais recente estável (Nextcloud Hub 26 Spring / v34) em vez de "latest".
# Isso ainda recebe patches de segurança e correções automaticamente dentro da série 34.x,
# mas evita um salto de major version não intencional (upgrades major do Nextcloud não
# podem ser pulados, então um "latest" descontrolado pode quebrar a instância).
# Para migrar de major version no futuro, atualize este número deliberadamente.
FROM nextcloud:34-apache
RUN apt update && apt install -y ffmpeg && rm -rf /var/lib/apt/lists/*