-- Scholarship detail: eligibility requirements and an external application link.

alter table public.scholarships
    add column if not exists eligibility text,
    add column if not exists application_url text;

comment on column public.scholarships.eligibility is 'Who may apply. Only verified official text.';
comment on column public.scholarships.application_url is 'Official application / learn-more link (ClubExpress or rocksinc.org).';
