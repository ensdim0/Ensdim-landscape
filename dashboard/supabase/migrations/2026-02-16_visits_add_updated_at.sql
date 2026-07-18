-- Add missing updated_at column to visits table
ALTER TABLE public.visits 
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();
