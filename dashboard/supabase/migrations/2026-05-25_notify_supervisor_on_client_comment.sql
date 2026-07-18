-- Notify the supervisor assigned to a line when a client comments on a visit
-- belonging to a contract in that line.
--
-- Path: client_comments.contract_id
--       → contracts.(zone_id OR block_id→blocks.zone_id)
--       → zones.line_id
--       → users.assigned_line_id

CREATE OR REPLACE FUNCTION public.notify_supervisor_on_client_comment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_supervisor_id UUID;
    v_line_id       UUID;
    v_author        TEXT;
    v_contract_code TEXT;
    v_visit_title   TEXT;
    v_visit_notes   TEXT;
    v_visit_date    DATE;
    v_visit_label   TEXT;
BEGIN
    IF TG_OP <> 'INSERT' THEN
        RETURN NEW;
    END IF;

    -- Resolve the line for this contract (zone_id direct or via block)
    SELECT COALESCE(z_direct.line_id, z_via_block.line_id)
    INTO v_line_id
    FROM public.contracts c
    LEFT JOIN public.zones z_direct   ON z_direct.id  = c.zone_id
    LEFT JOIN public.blocks b         ON b.id          = c.block_id
    LEFT JOIN public.zones z_via_block ON z_via_block.id = b.zone_id
    WHERE c.id = NEW.contract_id;

    IF v_line_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Find the supervisor assigned to this line
    SELECT id INTO v_supervisor_id
    FROM public.users
    WHERE assigned_line_id = v_line_id
    LIMIT 1;

    IF v_supervisor_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Build readable body
    v_author := COALESCE(NULLIF(TRIM(NEW.author_name), ''), 'العميل');

    SELECT code INTO v_contract_code
    FROM public.contracts
    WHERE id = NEW.contract_id;

    SELECT title, notes, visit_date
    INTO v_visit_title, v_visit_notes, v_visit_date
    FROM public.visits
    WHERE id = NEW.visit_id;

    v_visit_label := COALESCE(
        NULLIF(TRIM(v_visit_title), ''),
        NULLIF(TRIM(v_visit_notes), ''),
        CASE WHEN v_visit_date IS NOT NULL
             THEN TO_CHAR(v_visit_date, 'YYYY-MM-DD') END,
        'الزيارة'
    );

    BEGIN
        INSERT INTO public.notifications (user_id, title, body, meta)
        VALUES (
            v_supervisor_id,
            'تعليق عميل جديد',
            v_author || ' أضاف تعليقًا على ' || v_visit_label ||
                CASE WHEN v_contract_code IS NOT NULL
                     THEN ' (عقد ' || v_contract_code || ')'
                     ELSE '' END,
            jsonb_build_object(
                'type',        'client_comment',
                'contract_id', NEW.contract_id::text,
                'visit_id',    NEW.visit_id::text,
                'comment_id',  NEW.id::text,
                'author_name', v_author
            )
        );
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_supervisor_client_comment ON public.client_comments;
CREATE TRIGGER trg_notify_supervisor_client_comment
    AFTER INSERT ON public.client_comments
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_supervisor_on_client_comment();
