-- Payment due notifications: SQL function (called by daily cron) + INSERT trigger

-- ── Daily sync function ───────────────────────────────────────────────────────
-- Called by generate-payment-reminders edge function each morning.
-- Creates in-app notifications for contract payments due in 7 / 3 / 1 day or today.
-- Duplicate-safe: skips if a notification with same type+payment_id already exists.

CREATE OR REPLACE FUNCTION public.sync_payment_due_notifications()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment   record;
  v_days_left integer;
  v_type      text;
  v_title     text;
  v_body      text;
  v_exists    boolean;
  v_inserted  integer := 0;
BEGIN
  FOR v_payment IN
    SELECT
      cp.id,
      cp.amount,
      cp.due_date,
      cp.contract_id,
      c.user_id  AS client_id,
      c.code     AS contract_code
    FROM contract_payments cp
    JOIN contracts c ON c.id = cp.contract_id
    WHERE cp.due_date IS NOT NULL
      AND cp.due_date >= current_date
      AND (cp.gateway_status IS NULL OR cp.gateway_status = 'pending')
  LOOP
    v_days_left := (v_payment.due_date - current_date);

    CASE v_days_left
      WHEN 7 THEN
        v_type  := 'payment_due_7';
        v_title := 'تذكير: دفعة مستحقة خلال 7 أيام';
        v_body  := format('مبلغ %s KWD مستحق في %s (عقد %s)',
                          to_char(v_payment.amount, 'FM999999990.000'),
                          to_char(v_payment.due_date, 'DD/MM/YYYY'),
                          coalesce(v_payment.contract_code, ''));
      WHEN 3 THEN
        v_type  := 'payment_due_3';
        v_title := 'تذكير: دفعة مستحقة خلال 3 أيام';
        v_body  := format('مبلغ %s KWD مستحق في %s',
                          to_char(v_payment.amount, 'FM999999990.000'),
                          to_char(v_payment.due_date, 'DD/MM/YYYY'));
      WHEN 1 THEN
        v_type  := 'payment_due_1';
        v_title := 'تذكير: دفعة مستحقة غداً';
        v_body  := format('مبلغ %s KWD مستحق غداً — استعد للدفع',
                          to_char(v_payment.amount, 'FM999999990.000'));
      WHEN 0 THEN
        v_type  := 'payment_due_today';
        v_title := 'طلب دفع مستحق اليوم';
        v_body  := format('مبلغ %s KWD — اضغط للدفع الآن',
                          to_char(v_payment.amount, 'FM999999990.000'));
      ELSE
        CONTINUE;
    END CASE;

    -- Skip if already sent
    SELECT EXISTS(
      SELECT 1 FROM notifications n
      WHERE n.meta->>'type'       = v_type
        AND n.meta->>'payment_id' = v_payment.id::text
    ) INTO v_exists;

    IF NOT v_exists AND v_payment.client_id IS NOT NULL THEN
      INSERT INTO notifications(user_id, title, body, meta)
      VALUES(
        v_payment.client_id,
        v_title,
        v_body,
        jsonb_build_object(
          'type',          v_type,
          'payment_id',    v_payment.id,
          'contract_id',   v_payment.contract_id,
          'contract_code', v_payment.contract_code,
          'amount',        v_payment.amount,
          'due_date',      to_char(v_payment.due_date, 'YYYY-MM-DD')
        )
      );
      v_inserted := v_inserted + 1;
    END IF;
  END LOOP;

  RETURN v_inserted;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_payment_due_notifications() TO service_role;

-- ── INSERT trigger: instant notification when admin schedules a payment ───────

CREATE OR REPLACE FUNCTION public.notify_payment_scheduled_on_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client_id uuid;
  v_code      text;
BEGIN
  -- Only act on new scheduled payments (has due_date, not yet sent to gateway)
  IF NEW.due_date IS NULL OR NEW.gateway_status IS NOT NULL THEN
    RETURN NEW;
  END IF;

  SELECT c.user_id, c.code
  INTO v_client_id, v_code
  FROM contracts c
  WHERE c.id = NEW.contract_id;

  IF v_client_id IS NULL THEN
    RETURN NEW;
  END IF;

  INSERT INTO notifications(user_id, title, body, meta)
  VALUES(
    v_client_id,
    'جُدّلت دفعة جديدة',
    format('تم جدولة دفعة بقيمة %s KWD مستحقة في %s',
           to_char(NEW.amount, 'FM999999990.000'),
           to_char(NEW.due_date, 'DD/MM/YYYY')),
    jsonb_build_object(
      'type',          'payment_scheduled',
      'payment_id',    NEW.id,
      'contract_id',   NEW.contract_id,
      'contract_code', v_code,
      'amount',        NEW.amount,
      'due_date',      to_char(NEW.due_date, 'YYYY-MM-DD')
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_payment_scheduled ON contract_payments;
CREATE TRIGGER trg_notify_payment_scheduled
AFTER INSERT ON contract_payments
FOR EACH ROW EXECUTE FUNCTION public.notify_payment_scheduled_on_insert();

GRANT EXECUTE ON FUNCTION public.notify_payment_scheduled_on_insert() TO service_role;
GRANT EXECUTE ON FUNCTION public.notify_payment_scheduled_on_insert() TO authenticated;
