FROM python:3.11-alpine

# Upgrade OS packages to ensure latest security patches (Alpine uses musl libc, not glibc)
RUN apk update && apk upgrade --no-cache && rm -rf /var/cache/apk/*

WORKDIR /app

COPY azure-vote/requirements.txt .
# Upgrade pip, wheel and setuptools to fix CVE-2025-8869, CVE-2026-1703, CVE-2026-24049, CVE-2026-23949
RUN pip install --no-cache-dir --upgrade "pip>=25.3" "wheel>=0.46.2" "setuptools>=82.0.0" && \
    pip install --no-cache-dir -r requirements.txt

COPY azure-vote/ /app/

EXPOSE 80

CMD ["gunicorn", "--bind", "0.0.0.0:80", "--worker-class", "gthread", "--workers", "2", "--threads", "4", "--timeout", "60", "main:app"]
