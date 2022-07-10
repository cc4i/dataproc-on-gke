FROM us-central1-docker.pkg.dev/cloud-dataproc/spark/dataproc_2.0:latest

# Change to root temporarily so that it has permissions to create dirs and copy
# files.
USER root
RUN set -ex && \
    apt install bash


ENV SPARK_EXTRA_JARS_DIR=/opt/spark/jars/
RUN mkdir -p "${SPARK_EXTRA_JARS_DIR}" \
    && chown spark:spark "${SPARK_EXTRA_JARS_DIR}"
COPY --chown=spark:spark \
    conf/jmx_prometheus_javaagent-0.17.0.jar "${SPARK_EXTRA_JARS_DIR}"


COPY --chown=spark:spark conf/metrics.properties /usr/lib/spark/conf/
COPY --chown=spark:spark conf/prometheus-config.yml /usr/lib/spark/conf/

# (Optional) Set user back to `spark`.
USER spark
