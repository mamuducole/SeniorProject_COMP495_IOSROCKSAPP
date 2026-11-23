const app = document.querySelector('#app');
const sheet = document.querySelector('#sheet');
const status = document.querySelector('#status');
const esc = value => String(value).replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
const icons = {
  home: '<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V21h14V9.5M9 21v-7h6v7"/>',
  people: '<circle cx="9" cy="8" r="3"/><path d="M3 20v-2a6 6 0 0 1 12 0v2M16 5a3 3 0 0 1 0 6M17 14a5 5 0 0 1 4 5v1"/>',
  calendar: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M7 3v4M17 3v4M3 10h18"/>',
  book: '<path d="M12 6c-3-3-6-3-9-2v15c3-1 6-1 9 2m0-15c3-3 6-3 9-2v15c-3-1-6-1-9 2m0-15v15"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  chat: '<path d="M4 4h16v12H9l-5 4z"/>',
  pin: '<path d="M19 10c0 5-7 11-7 11S5 15 5 10a7 7 0 1 1 14 0Z"/><circle cx="12" cy="10" r="2"/>',
  bell: '<path d="M18 8a6 6 0 0 0-12 0c0 7-2 7-2 9h16c0-2-2-2-2-9M10 20h4"/>',
  back: '<path d="m15 18-6-6 6-6"/>',
  next: '<path d="m9 18 6-6-6-6"/>',
  close: '<path d="M5 5l14 14M19 5 5 19"/>',
  heart: '<path d="M20 5a5 5 0 0 0-7 0l-1 1-1-1a5 5 0 0 0-7 7l8 8 8-8a5 5 0 0 0 0-7Z"/>',
  search: '<circle cx="10" cy="10" r="6"/><path d="m15 15 5 5"/>',
  edit: '<path d="m4 20 4-.8L20 7l-3-3L5 16zM14 7l3 3"/>',
  award: '<path d="M12 3 3 8l9 5 9-5-9-5ZM6 10v5c3 3 9 3 12 0v-5M21 8v7"/>',
  grid: '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>'
};
const icon = name => `<svg class="icon" viewBox="0 0 24 24" aria-hidden="true">${icons[name] || icons.grid}</svg>`;
const tabs = [['home', 'Home', 'home'], ['connect', 'Connect', 'people'], ['events', 'Events', 'calendar'], ['learn', 'Learn', 'book'], ['you', 'You', 'user']];
const titles = { connect: 'Connect', events: 'Events', learn: 'Learn', you: 'You', community: 'Community Board', mentorship: 'Mentorship', mentors: 'Find a Mentor', directory: 'Member Directory', chapters: 'Chapters', news: 'News & Publications', reader: 'PDF Reader', settings: 'Settings', notifications: 'Notifications', more: 'More from ROCKS', scholarships: 'Scholarships', registration: 'Join The ROCKS', reset: 'Forgot Password' };
const tabFor = route => ({ community: 'connect', mentorship: 'connect', mentors: 'connect', directory: 'connect', chapters: 'connect', more: 'connect', news: 'learn', reader: 'learn', scholarships: 'learn', settings: 'you', notifications: 'home' }[route] || route);
const samples = [
  { id: 'one', author: 'Jessica Williams', body: "Honored to speak at today's Mentorship Mixer. Grateful for the leaders who invest in others. #ROCKSImpact #MentorshipMatters", likes: 45, liked: false, image: 'assets/rocksCommunityService.png', comments: ['Outstanding session — thank you for sharing your story.'] },
  { id: 'two', author: 'Marcus Johnson', body: 'Proud of our newest mentee cohort. Six months of goals, check-ins, and growth — this is what Service, Mentorship, and Leadership look like in action.', likes: 67, liked: false, comments: [] }
];
let posts = structuredClone(samples);
let events = [];
let publications = [];
let dataError = '';
let storageError = '';
let eventSection = 'upcoming';
let calendarView = false;
let month = new Date();
let selectedDay = '';
let toastTimer;
let activeRoute = '';
let returnRoute = 'home';
let readerDocument;
let readerPage = 1;
let readerZoom = 1;
const readerRenders = new WeakSet();
try {
  const saved = JSON.parse(localStorage.getItem('rocks-demo-posts') || 'null');
  if (saved !== null) {
    if (!Array.isArray(saved) || !saved.every(p => p && typeof p.id === 'string' && typeof p.author === 'string' && typeof p.body === 'string' && typeof p.likes === 'number' && typeof p.liked === 'boolean' && Array.isArray(p.comments) && p.comments.every(c => typeof c === 'string'))) throw new Error('Invalid saved demo data');
    posts = saved;
  }
  document.documentElement.dataset.theme = localStorage.getItem('rocks-demo-theme') || 'system';
} catch {
  storageError = 'Saved demo data could not be read. Sample data is shown instead.';
}
function notify(message) {
  status.textContent = message;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { status.textContent = ''; }, 4500);
}
function savePosts() {
  try { localStorage.setItem('rocks-demo-posts', JSON.stringify(posts)); return true; }
  catch { notify('Your changes could not be saved on this device.'); return false; }
}
function routeTo(route) {
  if (location.hash.slice(1) === route) { render(); return; }
  location.hash = route;
}
function back() {
  if (history.state?.rocksDemo) history.back();
  else routeTo(tabFor(activeRoute) !== activeRoute ? tabFor(activeRoute) : returnRoute);
}
function buttonRow(title, subtitle, image, target) {
  return `<button class="card row-button press" data-route="${target}"><span class="icon-tile">${icon(image)}</span><span class="copy"><span class="row-title">${esc(title)}</span><span class="muted">${esc(subtitle)}</span></span><span class="chevron">${icon('next')}</span></button>`;
}
function heading(kicker, title, description) {
  return `<div class="intro"><span class="eyebrow">${esc(kicker)}</span><h1>${esc(title)}</h1><p class="muted">${esc(description)}</p></div>`;
}
function brand() {
  return '<div class="brand"><img src="assets/rocksLogo.png" alt="The ROCKS, Inc. emblem"><div><strong>ROCKS</strong><small>CONNECT</small></div></div>';
}
function topbar(route) {
  const isRoot = tabs.some(([id]) => id === route);
  if (route === 'home') return '';
  return `<header class="topbar">${isRoot ? '' : `<button class="icon-button back" data-action="back" aria-label="Back">${icon('back')}</button>`}<span>${esc(titles[route] || 'ROCKS Connect')}</span></header>`;
}
function postCard(post) {
  const initials = post.author.split(/\s+/).slice(0, 2).map(part => part[0] || '').join('').toUpperCase();
  return `<article class="card post"><div class="post-head"><div class="avatar">${esc(initials)}</div><div class="copy"><strong>${esc(post.author)}</strong><div class="muted">Sample member post</div></div></div><p class="post-body">${esc(post.body)}</p>${post.image ? `<img class="post-image" src="${esc(post.image)}" alt="">` : ''}<div class="post-actions"><button data-action="like" data-id="${esc(post.id)}" aria-pressed="${post.liked}" aria-label="${post.liked ? 'Unlike' : 'Like'} post">${icon('heart')} ${post.likes}</button><button data-action="comments" data-id="${esc(post.id)}">${icon('chat')} ${post.comments.length} Comments</button></div></article>`;
}
function home() {
  return `<div class="stack home-stack"><div class="brand-header">${brand()}<button class="icon-button circle-button" data-route="notifications" aria-label="Notifications">${icon('bell')}</button></div>
    <div class="intro"><p class="muted">Good to see you, member.</p><h1>Your people.<br>Your potential.</h1></div>
    <div class="hero"><span class="eyebrow">ROOTED IN SERVICE</span><h2>Great leaders grow together.</h2><p>Find guidance and build meaningful connections.</p><button class="primary" data-route="mentorship">Find a Mentor</button></div>
    <div class="quick-grid">${[['Community','chat','community'],['Events','calendar','events'],['Chapters','pin','chapters']].map(([label, symbol, route]) => `<button class="quick" data-route="${route}">${icon(symbol)}${label}</button>`).join('')}</div>
    <section class="section"><div class="section-heading"><h2>Community</h2><button class="text-button" data-route="community">See all</button></div>${posts.slice(0,2).map(postCard).join('')}</section>
    <section class="section"><div class="section-heading"><h2>Upcoming Events</h2><button class="text-button" data-route="events">See all</button></div>${eventCards('upcoming', 2)}</section>
    ${buttonRow('News & Publications', 'Explore the publication library.', 'book', 'news')}
    <div class="card section"><h3>Our Mission</h3><p class="muted">Strengthen military officers and civilians by providing and promoting mentorship, professional leader development, scholarship and networking.</p></div></div>`;
}
function connect() {
  return `<div class="stack">${heading('CONNECTION. MENTORSHIP. COMMUNITY.', 'Find your people.', 'Connect with the ROCKS community, explore mentorship, and find your chapter.')}<div class="card-stack">${buttonRow('Community Board','Share updates and join the conversation.','chat','community')}${buttonRow('Mentorship','Find a mentor and view your connections.','people','mentorship')}${buttonRow('Member Directory','Discover members through the authorized directory.','people','directory')}${buttonRow('Chapters','Find chapters and interest groups near you.','pin','chapters')}${buttonRow('More from ROCKS','Organization information, resources, giving, and member tools.','grid','more')}</div></div>`;
}
function community() {
  return `<div class="stack">${heading('COMMUNITY', 'Stay connected.', 'Updates and conversations from the ROCKS community.')}<h3>All posts</h3><button class="card row-button" data-action="compose"><span class="avatar">RM</span><span class="muted">Share an update with the community…</span></button>${posts.map(postCard).join('')}</div>`;
}
function mentorship() {
  return `<div class="stack"><h1>Mentorship</h1><section class="card section"><div class="row-button"><span class="icon-tile">${icon('people')}</span><h2>CHAMP Mentorship Program</h2></div><p class="muted">CHAMP is The ROCKS, Inc. mentorship program connecting members with experienced leaders for guidance, professional development, and career growth.</p><button class="primary" data-action="champ">Explore CHAMP ↗</button></section>
  <div class="two-grid"><button class="card row-button" data-route="mentors"><span class="copy"><span class="icon-tile">${icon('people')}</span><strong>Find a Mentor</strong><span class="muted">Connect with experienced leaders</span></span></button><button class="card row-button" data-action="mentor-request"><span class="copy"><span class="icon-tile">${icon('user')}</span><strong>Become a Mentor</strong><span class="muted">Shape the next generation</span></span></button></div>
  <section class="section"><h2>Active connections</h2><p class="muted">No active mentorship connections in this demo.</p></section><section class="section"><h2>Requests</h2><p class="muted">No mentorship requests yet.</p></section><section class="section"><h2>Upcoming check-ins</h2><p class="muted">No upcoming check-ins.</p></section>${buttonRow('Find a Mentor','Browse sample mentor profiles.','people','mentors')}</div>`;
}
function mentors() {
  return `<div class="stack"><label class="field-label">Search mentors<input class="field" type="search" data-filter="mentors-list" placeholder="Search mentors"></label><p class="notice">Sample profiles only. Requests are not sent to real members.</p><div id="mentors-list" class="card-stack">${[['Marcus Johnson','Leadership and career development'],['Jessica Williams','Mentorship and professional growth']].map(([name, text]) => `<button class="card row-button filter-item" data-search="${esc(name + ' ' + text)}" data-action="mentor-detail" data-name="${esc(name)}"><span class="avatar">${name.split(' ').map(x => x[0]).join('')}</span><span class="copy"><strong>${esc(name)}</strong><span class="muted">${esc(text)}</span></span>${icon('next')}</button>`).join('')}</div><p class="muted filter-empty" hidden>No matching mentors.</p></div>`;
}
function directory() {
  return `<div class="stack"><label class="field-label">Search members<input class="field" type="search" placeholder="Search by name, chapter, or position"></label><div class="card section"><h2>Member directory</h2><p class="muted">Member profiles are not available in this demo. The authorized directory is managed by ROCKS.</p></div><button class="card row-button" data-action="directory-link"><span class="icon-tile">${icon('people')}</span><span class="copy"><strong>Official Member Directory</strong><span class="muted">Sign in on the official ROCKS website.</span></span>${icon('next')}</button>${buttonRow('Opted-in mentors','Browse sample mentorship profiles.','people','mentors')}</div>`;
}
const chapters = [
  ['Alamo ROCKS','Fort Sam Houston, TX'], ['All American Chapter ROCKS','Fort Liberty, NC'], ['Aloha Chapter of the ROCKS','Oahu, HI'], ['Buffalo Soldier ROCKS','Fort Leavenworth, KS'], ['Central Virginia ROCKS','Fort Gregg-Adams, VA'], ['El Paso ROCKS','Fort Bliss, TX'], ['Follow Me ROCKS','Fort Benning, GA'], ['Climb to Glory ROCKS','Fort Drum, NY'], ['Fort Huachuca chapter','Fort Huachuca, AZ'], ['Fort Riley ROCKS','Fort Riley, KS'], ['Gator ROCKS','Fort Polk, LA'], ['Gold Vault ROCKS','Fort Knox, KY'], ['Hampton Roads ROCKS','Hampton Roads, VA'], ['Hampton University ROCKS','Location not available'], ['Harry S. Truman ROCKS','Fort Leonard Wood, MO'], ['Henry O. Flipper ROCKS','West Point, NY'], ['Iron Horse ROCKS','Fort Carson, CO'], ['James Webster Smith Chapter','Fort Jackson, SC'], ['JBLM Rainer ROCKS','Joint Base Lewis-McChord, WA'], ['Marne ROCKS','Fort Stewart, GA'], ['Masters Chapter of the ROCKS','Fort Gordon, GA'], ['MG Charles Rogers ROCKS','Carlisle Barracks, PA'], ['Patriot ROCKS','Georgia Army National Guard, GA'], ['Phantom Warriors ROCKS','Fort Cavazos, TX'], ['Screaming Eagles ROCKS','Fort Campbell, KY'], ['Washington D.C. Chapter','Washington, DC'],
  ...['Balad, Iraq','Tampa, FL ROCKS','California National Guard','Camp Victory, Iraq','Chesapeake Bay ROCKS (CBRIG)','Coraopolis, PA','Ultimate Weapon ROCKS','High Desert ROCKS','Fort Riley, KS','Fort Sill, OK','Germany ROCKS','Honshu, Japan ROCKS (Rising Sun)','Mississippi National Guard','Rock Island Arsenal, IL','Kuwait','Saudi Arabia','South Korea Morning Calm','Virginia Military Institute','Wiesbaden Europe'].map(name => [`Interest Group: ${name}`, name])
];
function chapterList() {
  return `<div class="stack"><div class="dark-card section"><h1 style="font-family:Georgia,serif">Chapters</h1><p class="muted">Find a chapter near you and connect with a network of leaders.</p><label class="field-label"><span class="eyebrow">Search chapters</span><input class="field" type="search" data-filter="chapters-list" placeholder="Search by city, state, or chapter"></label></div><div id="chapters-list" class="card-stack">${chapters.map(([name, location]) => `<button class="card row-button filter-item" data-search="${esc(name + ' ' + location)}" data-action="chapter-detail" data-name="${esc(name)}" data-location="${esc(location)}"><span class="icon-tile">${icon('pin')}</span><span class="copy"><strong>${esc(name)}</strong><span class="muted">${esc(location)}</span></span>${icon('next')}</button>`).join('')}</div><p class="muted filter-empty" hidden>No matches. Try another name, city, state, or installation.</p></div>`;
}
function eventCards(section, limit = Infinity) {
  if (dataError && !events.length) return `<p class="error">${esc(dataError)}</p>`;
  const today = new Date(); today.setHours(0, 0, 0, 0);
  let visible = events.filter(event => {
    const date = new Date(`${event.event_date}T12:00:00`);
    return section === 'past' ? date < today : section === 'reminders' ? false : date >= today;
  });
  if (calendarView && selectedDay) visible = visible.filter(event => event.event_date === selectedDay);
  if (calendarView && !selectedDay) visible = [];
  visible = visible.slice(0, limit);
  if (!visible.length) return `<p class="muted">${calendarView && !selectedDay ? 'Select a date to see its events.' : 'No ROCKS events are currently available.'}</p>`;
  return visible.map(event => `<button class="card row-button" data-action="event-detail" data-id="${esc(event.id)}"><span class="icon-tile">${icon('calendar')}</span><span class="copy"><strong>${esc(event.title)}</strong><span class="muted">${esc(new Date(`${event.event_date}T12:00:00`).toLocaleDateString(undefined, { month: 'long', day: 'numeric', year: 'numeric' }))}</span></span>${icon('next')}</button>`).join('');
}
function calendar() {
  const year = month.getFullYear(), m = month.getMonth(), first = new Date(year, m, 1).getDay(), days = new Date(year, m + 1, 0).getDate();
  let cells = Array.from({length: first}, () => '<span></span>').join('');
  for (let day = 1; day <= days; day++) {
    const key = `${year}-${String(m + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    cells += `<button data-action="calendar-day" data-day="${key}" aria-label="${esc(new Date(year,m,day).toDateString())}" aria-pressed="${key === selectedDay}" class="${events.some(e => e.event_date === key) ? 'marked' : ''}">${day}</button>`;
  }
  return `<div class="card section"><div class="section-heading"><button class="icon-button" data-action="prev-month" aria-label="Previous month">${icon('back')}</button><strong>${esc(month.toLocaleDateString(undefined,{month:'long',year:'numeric'}))}</strong><button class="icon-button" data-action="next-month" aria-label="Next month">${icon('next')}</button></div><div class="calendar">${['S','M','T','W','T','F','S'].map(d => `<span class="muted">${d}</span>`).join('')}${cells}</div></div>`;
}
function eventsPage() {
  return `<div class="stack">${heading('MAKE TIME TO CONNECT', 'Show up. Grow together.', 'Browse verified events and set personal reminders.')}<div class="segmented" aria-label="Event sections">${[['upcoming','Upcoming Events'],['past','Past Events'],['reminders','Reminders']].map(([id,label]) => `<button data-action="event-section" data-value="${id}" aria-pressed="${eventSection === id}">${label}</button>`).join('')}</div><div class="segmented" aria-label="Event view"><button data-action="event-view" data-value="list" aria-pressed="${!calendarView}">List View</button><button data-action="event-view" data-value="calendar" aria-pressed="${calendarView}">Calendar View</button></div>${calendarView ? calendar() : ''}${eventCards(eventSection)}</div>`;
}
function learn() {
  return `<div class="stack">${heading('LEARN AND LEAD','Keep growing.','Publications, scholarships, and opportunities to develop as a leader.')}${buttonRow('ROCKS News & Publications','Explore ROCKS REFRESH and saved publications','book','news')}${buttonRow('Scholarship Center','Explore scholarship information and opportunities','award','scholarships')}<div class="hero" style="min-height:220px;background-image:linear-gradient(180deg,#0004,#000c),url('assets/rocksHeroLeadership.jpg')"><h1 style="font-family:Georgia,serif">Programs</h1><p>Our programs support mentorship, professional growth, scholarship, networking, and outreach.</p></div>${[['Mentorship','Guidance and professional development through mentor relationships.','mentorship'],['Leadership Development','Learn from experienced leaders and strengthen professional leadership.','more'],['Scholarships','Scholarship support for students and future military leaders.','scholarships'],['Networking','Build professional relationships across the ROCKS community.','more'],['Leadership Outreach','Connect students and future officers with experienced military professionals.','more'],['Community Service','Apply leadership through community involvement and outreach.','more']].map(([name,text,route]) => buttonRow(name,text,'award',route)).join('')}</div>`;
}
function news() {
  return `<div class="stack"><div class="dark-card section">${brand()}<h2>News & Publications</h2><p class="muted">Read and revisit publications from the ROCKS community.</p></div><label class="field-label">Search publications by title<input class="field" type="search" data-filter="publication-list" placeholder="Search publications by title"></label><div id="publication-list" class="section"><div class="card filter-item" data-search="sample demo pdf"><h3>Sample PDF reader</h3><p class="muted">A demonstration document, not an official publication.</p><button class="text-button" data-route="reader">Open sample PDF</button></div>${publications.length ? publications.map(p => `<div class="card filter-item" data-search="${esc(p.title)}"><strong>${esc(p.title)}</strong><p class="muted">Publication details are not configured in this demo.</p></div>`).join('') : '<p class="muted">No authorized publications are bundled with the iOS app.</p>'}</div><p class="muted filter-empty" hidden>No matching publications.</p><section class="section"><h2>News</h2><p class="muted">Sample articles</p>${[['Building the Next Generation of Leaders','Mentorship remains at the heart of the ROCKS community.'],['Connect With Your Local Chapter','Find opportunities to learn, serve, and grow together.']].map(([title,text]) => `<button class="card row-button" data-action="article" data-name="${esc(title)}" data-text="${esc(text)}"><span class="copy"><strong>${esc(title)}</strong><span class="muted">${esc(text)}</span></span>${icon('next')}</button>`).join('')}</section></div>`;
}
function reader() {
  return `<div class="stack"><p class="notice">Sample document for demonstration only. It is not an official ROCKS publication.</p><div class="reader-controls"><button data-action="pdf-prev" aria-label="Previous page" disabled>‹</button><span id="pdf-page" class="muted" role="status">Loading publication…</span><button data-action="pdf-next" aria-label="Next page" disabled>›</button><button data-action="pdf-zoom-out" aria-label="Zoom out" disabled>−</button><button data-action="pdf-zoom-in" aria-label="Zoom in" disabled>+</button></div><div class="reader"><canvas id="pdf-canvas" aria-label="Sample publication page"></canvas></div><p id="pdf-error" class="error" role="alert" hidden></p><a class="text-button center" href="assets/sample-demo.pdf" target="_blank" rel="noopener">Open PDF in browser ↗</a><p class="muted">Use the buttons to change pages or zoom. The browser link provides an accessible alternative when supported.</p></div>`;
}
async function loadReader() {
  const canvas = document.querySelector('#pdf-canvas');
  if (!canvas) return;
  try {
    const pdfjs = await import('./assets/pdf.mjs');
    pdfjs.GlobalWorkerOptions.workerSrc = './assets/pdf.worker.mjs';
    const document = await pdfjs.getDocument('assets/sample-demo.pdf').promise;
    if (!canvas.isConnected) { await document.destroy(); return; }
    readerDocument = document;
    readerPage = 1;
    readerZoom = 1;
    await drawReader();
  } catch (error) {
    if (!canvas.isConnected) return;
    const message = document.querySelector('#pdf-error');
    message.textContent = `Unable to open the PDF: ${error.message}. Use the browser link below.`;
    message.hidden = false;
    document.querySelector('#pdf-page').textContent = 'PDF unavailable';
  }
}
async function drawReader() {
  const canvas = document.querySelector('#pdf-canvas');
  if (!canvas || !readerDocument || readerRenders.has(canvas)) return;
  readerRenders.add(canvas);
  try {
    const page = await readerDocument.getPage(readerPage);
    if (!canvas.isConnected) return;
    const base = page.getViewport({ scale: 1 });
    const scale = canvas.parentElement.clientWidth / base.width * readerZoom;
    const viewport = page.getViewport({ scale });
    const density = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.floor(viewport.width * density);
    canvas.height = Math.floor(viewport.height * density);
    canvas.style.width = `${viewport.width}px`;
    canvas.style.height = `${viewport.height}px`;
    await page.render({ canvasContext: canvas.getContext('2d'), viewport, transform: [density, 0, 0, density, 0, 0] }).promise;
    if (!canvas.isConnected) return;
    document.querySelector('#pdf-page').textContent = `Page ${readerPage} of ${readerDocument.numPages}`;
    document.querySelector('[data-action="pdf-prev"]').disabled = readerPage <= 1;
    document.querySelector('[data-action="pdf-next"]').disabled = readerPage >= readerDocument.numPages;
    document.querySelector('[data-action="pdf-zoom-out"]').disabled = readerZoom <= 1;
    document.querySelector('[data-action="pdf-zoom-in"]').disabled = readerZoom >= 2;
  } catch (error) {
    if (!canvas.isConnected) return;
    const message = document.querySelector('#pdf-error');
    message.textContent = `Unable to render the PDF: ${error.message}. Use the browser link below.`;
    message.hidden = false;
  } finally { readerRenders.delete(canvas); }
}
function you() {
  return `<div class="stack"><div class="dark-card section"><img src="assets/rocksLogo.png" alt="The ROCKS, Inc. emblem" style="width:56px;height:56px;object-fit:contain"><div class="row-button"><span class="avatar">RM</span><span class="copy"><strong>ROCKS Member</strong><span class="muted">Account role: Demo member</span></span></div></div><div class="center section"><h3 style="font-family:Georgia,serif">“Men of Service. Leaders for Life.”</h3><hr style="width:100%;border:0;border-top:1px solid var(--gold)"></div><div class="two-grid">${[['My Events','calendar','events'],['Mentorship','people','mentorship'],['Scholarships','award','scholarships'],['Saved Publications','book','news']].map(([title,symbol,route]) => `<button class="quick" data-route="${route}">${icon(symbol)}${title}</button>`).join('')}</div><section class="section"><h2>Membership</h2><button class="primary" disabled>Renew Membership</button><p class="muted">Membership renewal is disabled in demo mode.</p></section>${buttonRow('Settings','Appearance and demo options','grid','settings')}<button class="text-button" data-route="login">Return to sign in</button></div>`;
}
function settings() {
  const theme = document.documentElement.dataset.theme || 'system';
  return `<div class="stack"><div class="card section"><h3>Appearance</h3><label class="field-label">Theme<select class="field" data-action="theme"><option value="system" ${theme === 'system' ? 'selected' : ''}>System</option><option value="light" ${theme === 'light' ? 'selected' : ''}>Light</option><option value="dark" ${theme === 'dark' ? 'selected' : ''}>Dark</option></select></label></div><button class="card row-button" data-action="reset-demo"><span class="copy"><strong>Reset demo community</strong><span class="muted">Remove posts, likes, and comments saved on this device.</span></span>${icon('next')}</button><p class="muted">This preview is not connected to production accounts or services.</p></div>`;
}
function login() {
  return `<main class="login stack"><div class="login-logo"><img src="assets/rocksLogo.png" alt="The ROCKS, Inc. emblem"></div><div class="center intro"><h2>Shaping Talent Through Mentorship</h2><p class="muted">Sign in to access your ROCKS community.</p></div><p class="notice">Demo only: real sign-in and registration are unavailable. Do not enter real credentials.</p><form class="stack" id="login-form"><label class="field-label">Email<input class="field" type="email" placeholder="Email" autocomplete="off"></label><label class="field-label">Password<input class="field" type="password" placeholder="Password" autocomplete="off"></label><button class="primary">Sign In</button></form><div class="login-actions"><button class="primary" data-route="home">Explore Demo</button><button class="text-button" data-route="registration">Create an Account</button><button class="text-button" data-route="reset">Forgot Password?</button></div></main>`;
}
function authPage(route) {
  if (route === 'reset') return `<div class="stack"><p class="notice">This is a demonstration. Password reset is not connected to an account service.</p><label class="field-label">Email<input class="field" type="email" placeholder="Email" autocomplete="off"></label><button class="primary" data-action="auth-unavailable">Send Reset Link</button></div>`;
  return `<div class="stack"><div class="center"><img src="assets/rocksLogo.png" width="110" height="110" style="object-fit:contain" alt="The ROCKS, Inc. emblem"></div><h2>Create your account</h2><p class="notice">Demo only. Do not enter real personal information or credentials; no account will be created.</p><form id="registration-form" class="stack"><label class="field-label">First name<input class="field" required autocomplete="off"></label><label class="field-label">Last name<input class="field" required autocomplete="off"></label><label class="field-label">Email<input class="field" type="email" required autocomplete="off"></label><label class="field-label">Password<input class="field" type="password" required autocomplete="off"></label><label class="field-label">Confirm password<input class="field" type="password" required autocomplete="off"></label><button class="primary">Create Account</button></form></div>`;
}
function generic(route) {
  if (route === 'notifications') return '<div class="card section"><h2>Notifications</h2><p class="muted">No notifications in this demo.</p></div>';
  if (route === 'scholarships') return '<div class="stack"><h1>Scholarships</h1><div class="card section"><h3>Scholarship Center</h3><p class="muted">Explore scholarship information through the official ROCKS organization. Demo data does not represent live applications.</p></div></div>';
  return `<div class="stack">${buttonRow('Community Board','Share updates and join the conversation.','chat','community')}${buttonRow('Chapters','Find a chapter near you.','pin','chapters')}${buttonRow('News & Publications','Read and revisit publications.','book','news')}</div>`;
}
function render() {
  const route = location.hash.slice(1) || 'login';
  if (sheet.open) sheet.close();
  if (activeRoute && activeRoute !== route) window.scrollTo(0, 0);
  activeRoute = route;
  if (route === 'login') { app.innerHTML = login(); return; }
  const screens = { home, connect, community, mentorship, mentors, directory, chapters: chapterList, events: eventsPage, learn, news, reader, you, settings, registration: () => authPage('registration'), reset: () => authPage('reset') };
  const content = (screens[route] || (() => generic(route)))();
  const auth = route === 'registration' || route === 'reset';
  const selected = tabFor(route);
  app.innerHTML = `${auth ? '' : '<div class="demo-banner">DEMO · Sample data; changes stay on this device</div>'}<main class="screen">${topbar(route)}${content}</main>${auth ? '' : `<nav class="tabbar" aria-label="Primary navigation">${tabs.map(([id,label,symbol]) => `<button data-route="${id}" ${selected === id ? 'aria-current="page"' : ''}>${icon(symbol)}<span>${label}</span></button>`).join('')}</nav>`}`;
  if (route === 'reader') void loadReader();
}
function openSheet(title, content) {
  sheet.innerHTML = `<div class="sheet-content"><div class="sheet-grip" aria-hidden="true"></div><div class="sheet-head"><h2 id="sheet-title">${esc(title)}</h2><button class="icon-button" data-action="close-sheet" aria-label="Close">${icon('close')}</button></div>${content}</div>`;
  sheet.showModal();
}
function selectedPost(id) { return posts.find(post => post.id === id); }
function commentsSheet(post) {
  openSheet('Post', `<div class="card post"><strong>${esc(post.author)}</strong><p class="post-body">${esc(post.body)}</p></div><h3>Comments</h3>${post.comments.length ? post.comments.map(comment => `<div class="card"><p class="post-body">${esc(comment)}</p><p class="muted">Sample or device-only comment</p></div>`).join('') : '<p class="muted">No comments yet.</p>'}<form id="comment-form" data-id="${esc(post.id)}" class="stack"><label class="field-label">Your comment<textarea class="field" name="body" maxlength="1000" required placeholder="Add a comment…"></textarea></label><button class="primary">Add Comment</button><p class="muted">Comments stay on this device and are not sent to members.</p></form>`);
}
document.addEventListener('click', event => {
  const target = event.target.closest('[data-route], [data-action]');
  if (!target || target.disabled) return;
  if (target.dataset.route) { returnRoute = activeRoute || 'home'; routeTo(target.dataset.route); return; }
  const action = target.dataset.action, id = target.dataset.id;
  if (action === 'back') back();
  else if (action === 'close-sheet') sheet.close();
  else if (action === 'compose') openSheet('Create Post', '<form id="post-form" class="stack"><label class="field-label">Your update<textarea class="field" name="body" maxlength="2000" required placeholder="Share an update with the community…"></textarea></label><button class="primary">Post</button><p class="muted">Your post stays on this device; it is not published to the real community.</p></form>');
  else if (action === 'like') {
    const post = selectedPost(id); if (!post) return;
    post.liked = !post.liked; post.likes += post.liked ? 1 : -1; savePosts(); render();
  } else if (action === 'comments') { const post = selectedPost(id); if (post) commentsSheet(post); }
  else if (action === 'event-section') { eventSection = target.dataset.value; selectedDay = ''; render(); }
  else if (action === 'event-view') { calendarView = target.dataset.value === 'calendar'; selectedDay = ''; render(); }
  else if (action === 'prev-month' || action === 'next-month') { month = new Date(month.getFullYear(), month.getMonth() + (action === 'prev-month' ? -1 : 1), 1); selectedDay = ''; render(); }
  else if (action === 'calendar-day') { selectedDay = target.dataset.day; render(); }
  else if (action === 'pdf-prev' || action === 'pdf-next' || action === 'pdf-zoom-out' || action === 'pdf-zoom-in') {
    if (readerRenders.has(document.querySelector('#pdf-canvas')) || !readerDocument) return;
    if (action === 'pdf-prev') readerPage = Math.max(1, readerPage - 1);
    if (action === 'pdf-next') readerPage = Math.min(readerDocument.numPages, readerPage + 1);
    if (action === 'pdf-zoom-out') readerZoom = Math.max(1, readerZoom - .25);
    if (action === 'pdf-zoom-in') readerZoom = Math.min(2, readerZoom + .25);
    void drawReader();
  }
  else if (action === 'event-detail') {
    const item = events.find(e => e.id === id); if (!item) return;
    openSheet('Event', `<div class="section"><h3>${esc(item.title)}</h3><p class="muted">${esc(item.event_date)}</p><p class="notice">This event is from the app's bundled calendar. Confirm current details with ROCKS.</p><a class="text-button" href="${esc(item.source_url)}" target="_blank" rel="noopener">Open official event calendar ↗</a><p class="muted">Device reminders are not available in this web demo.</p></div>`);
  } else if (action === 'chapter-detail') openSheet('Chapter', `<div class="section"><h3>${esc(target.dataset.name)}</h3><p class="muted">${esc(target.dataset.location)}</p><p class="muted">Listed in the iOS app's chapter directory. Contact information may change; verify it with ROCKS.</p></div>`);
  else if (action === 'mentor-detail') openSheet('Mentor', `<div class="section"><h3>${esc(target.dataset.name)}</h3><p class="notice">Sample mentor profile. No real mentorship request will be sent.</p><button class="primary" data-action="mentor-request">Request Mentorship</button></div>`);
  else if (action === 'mentor-request') openSheet('Mentorship request', '<form id="mentor-form" class="stack"><p class="notice">This is a sample request and will not be sent to a real mentor.</p><label class="field-label">Message<textarea class="field" name="body" required maxlength="1000" placeholder="Introduce yourself…"></textarea></label><button class="primary">Submit sample request</button></form>');
  else if (action === 'article') openSheet('News', `<div class="section"><h3>${esc(target.dataset.name)}</h3><p>${esc(target.dataset.text)}</p><p class="muted">Sample article</p></div>`);
  else if (action === 'champ' || action === 'directory-link') openSheet('Official ROCKS website', '<p class="muted">The official website is separate from this demo and may require a real member account.</p><a class="primary center" style="display:grid;place-items:center;text-decoration:none" href="https://rocksinc.org/" target="_blank" rel="noopener">Continue to rocksinc.org ↗</a>');
  else if (action === 'auth-unavailable') notify('Password reset is not available in this demo.');
  else if (action === 'reset-demo') openSheet('Reset demo community?', '<p class="muted">This removes demo posts, likes, and comments saved on this device.</p><button class="primary" data-action="confirm-reset">Reset demo community</button>');
  else if (action === 'confirm-reset') { posts = structuredClone(samples); const saved = savePosts(); sheet.close(); if (saved) notify('Demo community reset on this device.'); }
});
document.addEventListener('input', event => {
  const id = event.target.dataset.filter; if (!id) return;
  const list = document.getElementById(id); const query = event.target.value.trim().toLocaleLowerCase(); let count = 0;
  list.querySelectorAll('.filter-item').forEach(item => { item.hidden = !item.dataset.search.toLocaleLowerCase().includes(query); if (!item.hidden) count++; });
  const empty = list.parentElement.querySelector('.filter-empty'); if (empty) empty.hidden = count > 0;
});
document.addEventListener('change', event => {
  if (event.target.dataset.action !== 'theme') return;
  document.documentElement.dataset.theme = event.target.value;
  try { localStorage.setItem('rocks-demo-theme', event.target.value); } catch { notify('Appearance could not be saved on this device.'); }
});
document.addEventListener('submit', event => {
  event.preventDefault();
  const form = event.target;
  if (form.id === 'login-form' || form.id === 'registration-form') { notify('Real sign-in and registration are unavailable in this demo.'); return; }
  const body = new FormData(form).get('body')?.trim();
  if (!body) { notify('Please enter a message.'); return; }
  if (form.id === 'post-form') {
    posts.unshift({ id: crypto.randomUUID(), author: 'ROCKS Member', body, likes: 0, liked: false, comments: [] });
    const saved = savePosts(); sheet.close(); render(); if (saved) notify('Sample post saved on this device.');
  } else if (form.id === 'comment-form') {
    const post = selectedPost(form.dataset.id); if (!post) { notify('Post is no longer available.'); return; }
    post.comments.push(body); savePosts(); commentsSheetAfterClose(post);
  } else if (form.id === 'mentor-form') { sheet.close(); notify('Sample request completed; nothing was sent or saved.'); }
});
function commentsSheetAfterClose(post) { sheet.close(); render(); commentsSheet(post); }
window.addEventListener('hashchange', () => { history.replaceState({ rocksDemo: true }, ''); render(); });
history.replaceState({ rocksDemo: false }, '');
render();
if (storageError) notify(storageError);
try {
  const responses = await Promise.all(['assets/events.json', 'assets/publications.json'].map(url => fetch(url)));
  if (responses.some(response => !response.ok)) throw new Error('Bundled data could not be loaded.');
  [events, publications] = await Promise.all(responses.map(response => response.json()));
  if (!Array.isArray(events) || !Array.isArray(publications)) throw new Error('Bundled data has an invalid format.');
} catch {
  dataError = 'Bundled events and publications could not be loaded. Please reload the demo.';
  notify(dataError);
}
if (['home', 'events', 'news'].includes(activeRoute) && !sheet.open) render();
