-- Prevent URLs from being stored in visits.summary.

create or replace function public.sanitize_visit_summary(p_summary text)
returns text
language plpgsql
immutable
as $$
declare
  cleaned text;
begin
  if p_summary is null then
    return null;
  end if;

  cleaned := regexp_replace(p_summary, '\b(?:https?|ftp)://\S+', '', 'gi');
  cleaned := regexp_replace(cleaned, '\bwww\.\S+', '', 'gi');
  cleaned := regexp_replace(cleaned, '[ \t]{2,}', ' ', 'g');
  cleaned := regexp_replace(cleaned, '^\s+|\s+$', '', 'g');
  return cleaned;
end;
$$;

create or replace function public.trg_sanitize_visit_summary()
returns trigger
language plpgsql
as $$
begin
  new.summary := public.sanitize_visit_summary(new.summary);
  return new;
end;
$$;

drop trigger if exists trg_visits_sanitize_summary on public.visits;
create trigger trg_visits_sanitize_summary
before insert or update of summary on public.visits
for each row execute function public.trg_sanitize_visit_summary();
