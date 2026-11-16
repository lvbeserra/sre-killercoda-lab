-- Laboratorio exclusivo: PostgreSQL local, sem dados reais.
CREATE TABLE IF NOT EXISTS processed_jobs (
  job_id UUID PRIMARY KEY,
  bucket TEXT NOT NULL,
  object_key TEXT NOT NULL,
  worker_id TEXT NOT NULL,
  extracted_text TEXT NOT NULL DEFAULT '',
  processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_processed_jobs_processed_at ON processed_jobs (processed_at DESC);
