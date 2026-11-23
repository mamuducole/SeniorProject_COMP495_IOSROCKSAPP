-- Development-only public/example records. Do not add private member information here.
insert into public.chapters (name, short_name, description, city, state, country, is_active)
values
    ('National Capital Chapter', 'NCC', 'Example public chapter record for development.', 'Washington', 'DC', 'US', true),
    ('Fort Liberty Chapter', 'FLC', 'Example public chapter record for development.', 'Fayetteville', 'NC', 'US', true);

insert into public.events (title, description, category, starts_at, ends_at, timezone, venue_name, registration_required, is_published)
values
    ('2026 AUSA Annual Meeting & Exposition', 'A professional development forum. Join ROCKS members at the 2026 AUSA Annual Meeting & Exposition, October 12-14 in Washington, DC, featuring LTG Donna W. Martin, U.S. Army (Ret.), ROCKS National Chair.', 'conference', timestamptz '2026-10-12 09:00-04', timestamptz '2026-10-14 17:00-04', 'America/New_York', 'Walter E. Washington Convention Center, Washington, DC', true, true),
    ('JBLM Rainier ROCKS Fourth Anniversary', 'Celebrate four years of JBLM Rainier ROCKS. Keynote by LTG Donna W. Martin, U.S. Army (Ret.), ROCKS National Chair. Opening remarks by LTC MJ Jackson, Chapter President, followed by a facilitated Q&A and refreshments.', 'chapter', timestamptz '2026-10-29 16:30-07', timestamptz '2026-10-29 19:00-07', 'America/Los_Angeles', 'Lewis Army Museum, Joint Base Lewis-McChord', true, true),
    ('National Leadership Conference 2025', 'Flagship national conference for mentorship and leadership development.', 'conference', now() + interval '20 days', null, 'America/New_York', 'Atlanta, GA', true, true),
    ('ROCKS Mentorship Mixer', 'Example public event record for development.', 'mentorship', now() + interval '12 days', null, 'America/New_York', 'Virtual Event', false, true),
    ('Chapter Presidents Summit', 'Example public event record for development.', 'chapter', now() + interval '34 days', null, 'America/New_York', 'Arlington, VA', true, true),
    ('Leadership Development Roundtable', 'Example public event record for development.', 'professional_development', now() + interval '14 days', null, 'America/New_York', 'Online', true, true),
    ('Mentorship Connection Hour', 'Example public event record for development.', 'mentorship', now() + interval '28 days', null, 'America/New_York', 'Online', false, true),
    ('Community Service Day', 'Past example public event record for development.', 'community_service', now() - interval '21 days', null, 'America/New_York', 'Fort Liberty, NC', false, true);

insert into public.scholarships (title, summary, award_amount, deadline, is_active)
values
    ('ROCKS National Scholarship', 'Annual scholarship supporting members pursuing undergraduate and graduate degrees.', '$5,000', now() + interval '60 days', true),
    ('Emerging Leaders Grant', 'Supports professional development and leadership coursework.', '$1,500', now() + interval '45 days', true),
    ('Legacy of Leadership Award', 'Honors members demonstrating sustained mentorship and community service.', '$2,500', now() + interval '90 days', true);

-- Note: posts, mentorship profiles, requests, connections, and notifications reference
-- auth-backed profiles. Seed them after demo users exist in auth.users, or rely on the
-- app's mock repositories which provide demo feed/mentorship content without credentials.
