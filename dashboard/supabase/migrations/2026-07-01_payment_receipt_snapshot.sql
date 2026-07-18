-- Stores a frozen snapshot of receipt data at payment time.
-- Prevents old receipts from showing updated totals when new payments are added.
ALTER TABLE contract_payments
  ADD COLUMN IF NOT EXISTS receipt_data jsonb;

-- Clients can read their own payment snapshots (already covered by existing RLS on contract_payments)
-- No additional RLS needed: receipt_data is just another column on the same row.

COMMENT ON COLUMN contract_payments.receipt_data IS
  'Frozen snapshot saved at payment time: contractType, contractTotalValue, totalPaidAtTime, remainingAtTime, totalVisitsCount, completedVisitsCount, palmInfo, contractStartDate, contractEndDate';
