-- Payment notifications cleanup + admin late-payment alert:
--  1. Remove "payment_scheduled" (insert trigger) and "payment_due_7" notification
--     types entirely — neither ever reached the client via push, and no client
--     UI surfaces in-app rows, so they were silently dead.
--  2. Add an in-app (bell-only, no push) notification for admins when a payment
--     becomes late, mirroring the existing client-facing "payment_late" alert.

DROP TRIGGER IF EXISTS trg_notify_payment_scheduled ON contract_payments;
DROP FUNCTION IF EXISTS public.notify_payment_scheduled_on_insert();

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
  v_admin_ids uuid[];
  v_admin_id  uuid;
BEGIN
  SELECT array_agg(ur.user_id) INTO v_admin_ids
  FROM user_roles ur
  JOIN roles r ON r.id = ur.role_id
  WHERE r.name = 'admin';

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
      AND (cp.gateway_status IS NULL OR cp.gateway_status IN ('pending', 'failed', 'cancelled'))
  LOOP
    v_days_left := (v_payment.due_date - current_date);

    IF v_days_left > 3 THEN
      CONTINUE;
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
          CONTINUE;
      END CASE;
    END IF;

    -- Skip if already sent to the client
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

    -- Late payments: also alert admins (in-app bell only, no push)
    IF v_type = 'payment_late' AND v_admin_ids IS NOT NULL THEN
      FOREACH v_admin_id IN ARRAY v_admin_ids LOOP
        SELECT EXISTS(
          SELECT 1 FROM notifications n
          WHERE n.user_id          = v_admin_id
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
  END LOOP;

  RETURN v_inserted;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_payment_due_notifications() TO service_role;
