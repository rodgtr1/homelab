# Installing Postgres in Kubernetes

## 1. Create secret
```yaml
kubectl create secret generic postgres-credentials -n database \
  --from-literal=POSTGRES_PASSWORD='AdminPassword' \
  --from-literal=APP_DB_PASSWORD='AUserPassword'
```

## 2. Create the directories on host (worker)
### Create directories:
```sh
sudo mkdir -p /data/postgres-data /data/postgres-dump
```

### Set ownership to user 1001 (Bitnami PostgreSQL user)
```sh
sudo chown -R 1001:1001 /data/postgres-data
sudo chown -R 1001:1001 /data/postgres-dump
```

### Set appropriate permissions
```sh
sudo chmod -R 750 /data/postgres-data
sudo chmod -R 750 /data/postgres-dump
```

## 3. Create persistent volumes
```sh
k create -f postgres-pv.yaml
```

## 4. Install via Helm chart with custom values.yaml
```sh
helm install postgres oci://registry-1.docker.io/bitnamicharts/postgresql -n database --values postgres-values.yaml
```

## 5. Customize as needed
Can exec into the pod with:

```sh
k exec -it -n database postgres-postgresql-0 -- /opt/bitnami/scripts/postgresql/entrypoint.sh /bin/bash
```

Can login with the following command and enter your admin password on the subsequent prompt
```sh
psql -U postgres
```

Can then create users, grant privileges, create databases, tables, etc. Some examples are:

```sh
CREATE DATABASE homelabdb;

CREATE USER myuser WITH PASSWORD 'your-password';

GRANT ALL PRIVILEGES ON DATABASE homelabdb TO myuser;
GRANT ALL PRIVILEGES ON SCHEMA public TO myuser;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO myuser;

CREATE TABLE daily_steps (
    id SERIAL PRIMARY KEY,
    date DATE UNIQUE NOT NULL,
    steps INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

# Connect to the database with postgres user
\c homelabdb postgres

# Change table ownership to travis
ALTER TABLE daily_steps OWNER TO travis;

# Grant all privileges explicitly
GRANT ALL PRIVILEGES ON TABLE daily_steps TO travis;
GRANT ALL PRIVILEGES ON SCHEMA public TO travis;

#Verify permissions
\z daily_steps
```

