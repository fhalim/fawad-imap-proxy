FROM python:3.11-slim

RUN pip install --no-cache-dir emailproxy

WORKDIR /config

ENTRYPOINT ["emailproxy"]
CMD ["--no-gui", "--config-file", "/config/emailproxy.config", \
     "--cache-store", "/config/tokens/credstore.config", \
     "--local-server-auth"]
