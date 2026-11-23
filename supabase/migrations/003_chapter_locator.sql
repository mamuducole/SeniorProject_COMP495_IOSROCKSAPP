-- Chapter Locator: verified contact and address details for the map and detail views.
-- The base schema (001) already provides latitude/longitude, installation, email, phone, website.

alter table public.chapters
    add column if not exists mailing_address text,
    add column if not exists contact_person text;

comment on column public.chapters.mailing_address is 'Official chapter mailing address. Only populated with verified data.';
comment on column public.chapters.contact_person is 'Chapter point of contact (e.g., president). Only populated with verified data.';
