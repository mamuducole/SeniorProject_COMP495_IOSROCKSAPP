-- Chapter details verified against https://www.rocksinc.org/content.aspx?page_id=225&club_id=459944.
-- Leave unavailable fields NULL; never replace chapter mailing addresses with installation addresses.

alter table public.chapters
    alter column city drop not null,
    alter column state drop not null;

do $$
declare
    chapter_record record;
    existing_id uuid;
begin
    for chapter_record in
        select *
        from (values
            (
                '30000000-0000-0000-0000-000000000001'::uuid, 'Alamo ROCKS',
                'Fort Sam Houston', 'TX', 'Fort Sam Houston',
                'PO BOX 340378' || E'\n' || 'Fort Sam Houston, TX 78234',
                'LTC Michelle Jefferson', 'ftsamhoustonrocks@gmail.com', null::text,
                array['alamorocks', 'alamorocksftsamhoustontx']::text[]
            ),
            (
                '30000000-0000-0000-0000-000000000002'::uuid, 'All American Chapter ROCKS',
                null::text, 'NC', 'Fort Liberty',
                'Post Office Box 73233' || E'\n' || 'Fort Bragg, NC 28310',
                'MAJ Deirdra Johnson', 'abnrocks1@gmail.com', null::text,
                array['allamericanchapterrocks', 'allamericanchapterrocksfortlibertync']::text[]
            ),
            (
                '30000000-0000-0000-0000-000000000003'::uuid, 'Aloha Chapter of the ROCKS',
                null::text, 'HI', null::text,
                'P.O. Box 30797' || E'\n' || 'Honolulu, HI 96820',
                'LTC Brandon Richards', 'brandon.w.richards@gmail.com', null::text,
                array['alohachapteroftherocks', 'alohachapteroftherocksoahuhi']::text[]
            ),
            (
                '30000000-0000-0000-0000-000000000004'::uuid, 'Buffalo Soldier ROCKS',
                'Fort Leavenworth', 'KS', 'Fort Leavenworth',
                'P.O. Box 3122' || E'\n' || 'Fort Leavenworth, KS 66027',
                'MAJ Johnnathan Foster', 'jonwoo4life@gmail.com', 'https://www.rocksinc.org/',
                array['buffalosoldierrocks', 'buffalosoldierrocksfortleavenworthks']::text[]
            ),
            (
                '30000000-0000-0000-0000-000000000008'::uuid, 'Climb to Glory ROCKS',
                null::text, 'NY', 'Fort Drum', null::text,
                'Alan Greene', 'climbtogloryrocks@gmail.com', null::text,
                array['climbtogloryrocks', 'fortdrumnyclimbtogloryrocks']::text[]
            ),
            (
                '30000000-0000-0000-0000-000000000009'::uuid, 'Fort Huachuca chapter',
                null::text, 'AZ', 'Fort Huachuca', null::text,
                'CW4 Frederick T. Joyce', 'huachucarocksinc@gmail.com', null::text,
                array['forthuachucachapter', 'forthuachucarocks', 'forthuachucaaz']::text[]
            ),
            (
                '30000000-0000-0000-0000-000000000013'::uuid, 'Hampton Roads ROCKS',
                'Hampton Roads', 'VA', null::text,
                'P.O. Box 4499' || E'\n' || 'Fort Eustis, VA 23604',
                'COL (R) Julius Coats', null::text, null::text,
                array['hamptonroadsrocks', 'hamptonroadsrocksva']::text[]
            ),
            (
                '30000000-0000-0000-0000-000000000014'::uuid, 'Hampton University ROCKS',
                null::text, null::text, null::text, null::text,
                'Alyssa M. Sutton', 'hamptonuniversityrocks@gmail.com',
                'https://www.rocksinc.org/content.aspx?page_id=22&club_id=459944&module_id=663331&actr=4',
                array['hamptonuniversityrocks']::text[]
            ),
            (
                '30000000-0000-0000-0000-000000000016'::uuid, 'Henry O. Flipper ROCKS',
                'West Point', 'NY', 'West Point',
                'P.O. Box 174' || E'\n' || 'West Point, NY 10996',
                'COL John Baskerville', 'john.baskerville@wespoint.edu', null::text,
                array['henryoflipperrocks', 'henryoflipperrockswestpointny']::text[]
            ),
            (
                '30000000-0000-0000-0000-000000000019'::uuid, 'JBLM Rainer ROCKS',
                null::text, 'WA', 'Joint Base Lewis-McChord', null::text,
                'MAJ Mikhail (MJ) Jackson', 'jblmrainierrocks2021@gmail.com', null::text,
                array['jblmrainerrocks', 'jblmrainierrocks', 'jblmrainierrocksftlewismcchordwa']::text[]
            ),
            (
                '30000000-0000-0000-0000-000000000022'::uuid, 'MG Charles Rogers ROCKS',
                null::text, 'PA', 'Carlisle Barracks', null::text,
                'LTC Timothy Johnson', 'timothy.Johnson.mil@armywarcollege.edu', null::text,
                array['mgcharlesrogersrocks', 'mgcharlesrogersrocksawc', 'mgcharlesrogersrocksawccarlislebarracks']::text[]
            ),
            (
                '30000000-0000-0000-0000-000000000024'::uuid, 'Phantom Warriors ROCKS',
                null::text, 'TX', 'Fort Cavazos', null::text,
                'LTC Taneshia Johnson', 'phantomwarriorrocks2@gmail.com',
                'https://www.facebook.com/FortHoodPhantomWarriorROCKS/',
                array['phantomwarriorsrocks', 'phantomwarriorsrocksfortcavazostx']::text[]
            ),
            (
                '30000000-0000-0000-0000-000000000026'::uuid, 'Washington D.C. Chapter',
                'Washington', 'DC', null::text,
                'c/o WSC Associates, LLP' || E'\n' || 'P.O. Box 47435' || E'\n' || 'Forestville, MD 20753',
                'LTC (Ret) Kimberlee Short', 'support@therocksdc.org', 'https://therocksdc.org/',
                array['washingtondcchapter', 'washingtondc']::text[]
            )
        ) as requested(
            id, name, city, state, installation, mailing_address,
            contact_person, email, website, match_names
        )
    loop
        select chapters.id
        into existing_id
        from public.chapters as chapters
        where regexp_replace(lower(coalesce(chapters.name, '')), '[^a-z0-9]', '', 'g')
            = any(chapter_record.match_names)
        order by (chapters.id = chapter_record.id) desc, chapters.created_at
        limit 1;

        if existing_id is null then
            if exists (select 1 from public.chapters where id = chapter_record.id) then
                raise exception 'Stable chapter ID % is already used by another chapter', chapter_record.id;
            end if;

            insert into public.chapters (
                id, name, city, state, installation, mailing_address, contact_person,
                email, website, description, is_active, updated_at
            )
            values (
                chapter_record.id, chapter_record.name, chapter_record.city, chapter_record.state,
                chapter_record.installation, chapter_record.mailing_address, chapter_record.contact_person,
                chapter_record.email, chapter_record.website,
                case
                    when chapter_record.name = 'Aloha Chapter of the ROCKS'
                        then 'Official chapter finder lists the chapter in Oahu, HI.'
                    else 'Official ROCKS, Inc. chapter-finder listing.'
                end,
                true, now()
            );
        else
            update public.chapters as chapters
            set name = chapter_record.name,
                city = coalesce(nullif(chapters.city, ''), chapter_record.city),
                state = coalesce(nullif(chapters.state, ''), chapter_record.state),
                installation = coalesce(nullif(chapters.installation, ''), chapter_record.installation),
                mailing_address = coalesce(nullif(chapters.mailing_address, ''), chapter_record.mailing_address),
                contact_person = coalesce(nullif(chapters.contact_person, ''), chapter_record.contact_person),
                email = coalesce(nullif(chapters.email, ''), chapter_record.email),
                website = coalesce(nullif(chapters.website, ''), chapter_record.website),
                description = case
                    when chapter_record.name = 'Aloha Chapter of the ROCKS'
                        then 'Official chapter finder lists the chapter in Oahu, HI.'
                    else coalesce(nullif(chapters.description, ''), 'Official ROCKS, Inc. chapter-finder listing.')
                end,
                is_active = true,
                updated_at = now()
            where chapters.id = existing_id;
        end if;
    end loop;
end;
$$;

drop policy if exists "authorized administrators can manage chapters" on public.chapters;

create policy "authorized administrators can manage chapters"
    on public.chapters
    for all
    to authenticated
    using (
        exists (
            select 1
            from public.profiles
            where profiles.id = auth.uid()
              and (
                  profiles.role = 'national_admin'
                  or (profiles.role = 'chapter_admin' and profiles.chapter_id = chapters.id)
              )
        )
    )
    with check (
        exists (
            select 1
            from public.profiles
            where profiles.id = auth.uid()
              and (
                  profiles.role = 'national_admin'
                  or (profiles.role = 'chapter_admin' and profiles.chapter_id = chapters.id)
              )
        )
    );
