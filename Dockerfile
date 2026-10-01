# ================================================================
# COBOL Core Banking API image: GnuCOBOL + the COBOL system + the
# FastAPI wrapper. Data lives in the /var/lib/cbs volume.
# ================================================================
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        gnucobol python3 python3-venv ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --uid 10001 cbs

WORKDIR /app

# Python dependencies first (better layer caching).
COPY api/requirements.txt api/requirements.txt
RUN python3 -m venv /opt/venv \
 && /opt/venv/bin/pip install --no-cache-dir -r api/requirements.txt

# The project, then compile the COBOL system (fails the image build on
# any COBOL compile error).
COPY . .
RUN ./scripts/build.sh && rm -rf bin/obj \
 && mkdir -p /var/lib/cbs/data /var/lib/cbs/reports \
 && chown -R cbs:cbs /var/lib/cbs

ENV PATH=/opt/venv/bin:$PATH \
    PYTHONPATH=/app/api \
    CBS_DATA_DIR=/var/lib/cbs/data \
    CBS_REPORT_DIR=/var/lib/cbs/reports \
    CBS_CONFIG_FILE=/app/config/cbs.conf

USER cbs
VOLUME ["/var/lib/cbs"]
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s \
  CMD python3 -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=4).status == 200 else 1)"

ENTRYPOINT ["/app/deploy/entrypoint.sh"]
