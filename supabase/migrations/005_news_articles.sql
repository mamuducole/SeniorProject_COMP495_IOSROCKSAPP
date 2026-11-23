create table public.news_articles (
    id uuid primary key default gen_random_uuid(),
    author_id uuid references public.profiles(id) on delete set null,
    title text not null,
    summary text not null,
    body text not null,
    category text not null default 'News',
    is_featured boolean not null default false,
    is_published boolean not null default false,
    published_at timestamptz not null default now(),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint news_articles_title_nonempty check (length(trim(title)) > 0),
    constraint news_articles_summary_nonempty check (length(trim(summary)) > 0),
    constraint news_articles_body_nonempty check (length(trim(body)) > 0)
);

create index news_articles_published_idx
    on public.news_articles (published_at desc)
    where is_published = true;

alter table public.news_articles enable row level security;

create policy "anyone can read published news"
    on public.news_articles for select
    using (is_published = true);

create policy "national admins can publish news"
    on public.news_articles for insert to authenticated
    with check (
        author_id = auth.uid()
        and exists (
            select 1 from public.profiles p
            where p.id = auth.uid() and p.role = 'national_admin'
        )
    );

create policy "national admins can update news"
    on public.news_articles for update to authenticated
    using (
        exists (
            select 1 from public.profiles p
            where p.id = auth.uid() and p.role = 'national_admin'
        )
    )
    with check (
        exists (
            select 1 from public.profiles p
            where p.id = auth.uid() and p.role = 'national_admin'
        )
    );

create policy "national admins can delete news"
    on public.news_articles for delete to authenticated
    using (
        exists (
            select 1 from public.profiles p
            where p.id = auth.uid() and p.role = 'national_admin'
        )
    );
