# System Architecture

## Layer Stack

| Layer                    | MVP Technology                        | Production                           |
|--------------------------|---------------------------------------|--------------------------------------|
| Operational Systems      | Spring Boot / NestJS, PostgreSQL, Redis | Quarkus, PostgreSQL + PostGIS       |
| GPS / Telemetry Ingestion| Kafka or Redpanda                     | MQTT + Kafka                         |
| Data Lake / Warehouse    | MinIO/S3 + ClickHouse                 | Apache Iceberg / Delta Lake + Trino  |
| Data Transformation      | dbt + Python                          | dbt + Apache Spark                   |
| Feature Engineering      | Python, Pandas                        | Feast                                |
| ML Training              | XGBoost, Prophet, scikit-learn        | XGBoost, PyTorch                     |
| Model Registry           | MLflow                                | MLflow Model Registry                |
| Model Serving API        | FastAPI                               | KServe or FastAPI                    |
| Workflow Orchestration   | —                                     | Airflow / Dagster / Argo Workflows   |
| Business Apps            | React / Next.js, Flutter              | Same                                 |
| Monitoring               | —                                     | Prometheus + Grafana                 |
| Auth                     | —                                     | Keycloak                             |
| API Gateway              | —                                     | Apache APISIX or Kong                |
| CI/CD                    | GitHub Actions                        | GitHub Actions + ArgoCD              |
