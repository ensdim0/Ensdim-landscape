-- Extracts the per-payment reminder evaluation out of sync_payment_due_notifications()
-- into a standalone function, so it can also be called immediately right after a
-- payment is scheduled (instead of waiting for the next daily cron run, which could
-- be up to 24h later — missing the exact "due in 3 days" window for payments
-- scheduled same-day with due_date = today+3).

CREATE OR REPLACE FUNCTION public.evaluate_payment_due_notification(p_payment_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment   record;
  v_days_left integer;
  v_type      text;
  v_title     text;
  v_body      text;
  v_exists    boolean;
  v_admin_ids uuid[];
  v_admin_id  uuid;
BEGIN
  SELECT
    cp.id, cp.amount, cp.due_date, cp.contract_id,
    c.user_id AS client_id, c.code AS contract_code
  INTO v_payment
  FROM contract_payments cp
  JOIN contracts c ON c.id = cp.contract_id
  WHERE cp.id = p_payment_id
    AND cp.due_date IS NOT NULL
    AND (cp.gateway_status IS NULL OR cp.gateway_status IN ('pending', 'failed', 'cancelled'));

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  v_days_left := (v_payment.due_date - current_date);

  IF v_days_left > 3 THEN
    RETURN NULL;
  ELSIF v_days_left < 0 THEN
    v_type  := 'payment_late';
    v_title := 'دفعة متأخرة';
    v_body  := format('مبلغ %s KWD متأخر عن السداد منذ %s يوم (عقد %s)',
                      to_char(v_payment.amount, 'FM999999990.000'),
                      abs(v_days_left),
                      coalesce(v_payment.contract_code, ''));
  ELSE
    CASE v_days_left
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
        RETURN NULL;
    END CASE;
  END IF;

  -- Skip if already sent to the client
  SELECT EXISTS(
    SELECT 1 FROM notifications n
    WHERE n.meta->>'type'       = v_type
      AND n.meta->>'payment_id' = v_payment.id::text
  ) INTO v_exists;

  IF v_exists OR v_payment.client_id IS NULL THEN
    RETURN NULL;
  END IF;

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

  -- Late payments: also alert admins (in-app bell only, no push)
  IF v_type = 'payment_late' THEN
    SELECT array_agg(ur.user_id) INTO v_admin_ids
    FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE r.name = 'admin';

    IF v_admin_ids IS NOT NULL THEN
      FOREACH v_admin_id IN ARRAY v_admin_ids LOOP
        SELECT EXISTS(
          SELECT 1 FROM notifications n
          WHERE n.user_id            = v_admin_id
            AND n.meta->>'type'       = 'payment_late_admin'
            AND n.meta->>'payment_id' = v_payment.id::text
        ) INTO v_exists;

        IF NOT v_exists THEN
          INSERT INTO notifications(user_id, title, body, meta)
          VALUES(
            v_admin_id,
            'دفعة متأخرة',
            format('دفعة بقيمة %s KWD متأخرة عن السداد (عقد %s)',
                  to_char(v_payment.amount, 'FM999999990.000'),
                  coalesce(v_payment.contract_code, '')),
            jsonb_build_object(
              'type',          'payment_late_admin',
              'payment_id',    v_payment.id,
              'contract_id',   v_payment.contract_id,
              'contract_code', v_payment.contract_code,
              'amount',        v_payment.amount
            )
          );
        END IF;
      END LOOP;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'type',        v_type,
    'client_id',   v_payment.client_id,
    'contract_id', v_payment.contract_id,
    'amount',      v_payment.amount
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.evaluate_payment_due_notification(uuid) TO service_role;

-- sync_payment_due_notifications() now just loops candidate payments and
-- delegates the per-row evaluation to the function above (DRY).
CREATE OR REPLACE FUNCTION public.sync_payment_due_notifications()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment_id uuid;
  v_result     jsonb;
  v_inserted   integer := 0;
BEGIN
  FOR v_payment_id IN
    SELECT cp.id
    FROM contract_payments cp
    WHERE cp.due_date IS NOT NULL
      AND (cp.gateway_status IS NULL OR cp.gateway_status IN ('pending', 'failed', 'cancelled'))
  LOOP
    v_result := public.evaluate_payment_due_notification(v_payment_id);
    IF v_result IS NOT NULL THEN
      v_inserted := v_inserted + 1;
    END IF;
  END LOOP;

  RETURN v_inserted;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_payment_due_notifications() TO service_role;
