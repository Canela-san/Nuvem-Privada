FROM nextcloud:latest
RUN apt update && apt install -y ffmpeg && rm -rf /var/lib/apt/lists/*
