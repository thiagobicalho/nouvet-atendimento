# Imagem mínima do importador standalone (Story 1.1, AD-15) -- mesma base Python
# (3.12) usada para rodar os testes de unidade neste ambiente de dev, `-slim` porque o
# programa não precisa de mais nada além de `psycopg2-binary` (já traz libpq
# vendorizado, sem precisar instalar `libpq-dev`/`gcc`).
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY importador ./importador

# Nunca copia CSV/export para dentro da imagem -- o export é montado em runtime via
# volume (docker-compose.yml), fora do repositório e fora da imagem (NFR-6).
ENTRYPOINT ["python", "-m", "importador.main"]
