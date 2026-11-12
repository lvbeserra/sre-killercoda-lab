-- Schema do exercício: criado APENAS quando o volume PostgreSQL é inicializado.
-- Sem dados pessoais ou credenciais.
CREATE TABLE IF NOT EXISTS incidents (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    service VARCHAR(80) NOT NULL,
    severity VARCHAR(2) NOT NULL CHECK (severity IN ('P1', 'P2', 'P3')),
    status VARCHAR(16) NOT NULL DEFAULT 'OPEN'
      CHECK (status IN ('OPEN', 'INVESTIGATING', 'RESOLVED')),
    description VARCHAR(500) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS incidents_created_at_idx ON incidents(created_at DESC);
