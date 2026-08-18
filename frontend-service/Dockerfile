FROM python:3.11-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN python -m venv /opt/venv \
  && /opt/venv/bin/pip install --upgrade pip \
  && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

FROM python:3.11-slim AS runtime

LABEL maintainer="Rajesh Grievance Team" \
      service="frontend-service" \
      version="1.0"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" 
    
WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY static/ static/
COPY templates/ templates/
COPY . .

RUN useradd --create-home --uid 1000 appuser \
  && chown -R appuser:appuser /app
USER appuser

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request, os; urllib.request.urlopen('http://localhost:' + os.environ.get('PORT','5000') + '/healthz').read()" || exit 1

EXPOSE 5000

CMD ["sh", "-c", "gunicorn --workers 3 --bind 0.0.0.0:${PORT} --access-logfile - app:app"]
