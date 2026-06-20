// popup.js — StudyFlow Tracker v2

import {
  getAllProfiles, getActiveProfile, saveActiveProfile, createProfile,
  deleteProfile, switchProfile, renameProfile,
  getDomains, saveDomains, addDomain, deleteDomain,
  getTasks, addTask, updateTask, deleteTask,
  getEvents, addEvent, updateEvent, deleteEvent,
  getGoals, addGoal, updateGoalProgress, deleteGoal,
  logSession,
  exportAllProfiles, importData,
  getTheme, setTheme,
  generateId,
  PROFILE_COLORS, PROFILE_EMOJIS, DOMAIN_ICONS, DOMAIN_COLORS
} from './storage.js';

// ── State ───────────────────────────────────────────────────────────────────
let state = {
  profile: null, activeProfile: null, profiles: {},
  domains: [],
  tasks: [], events: [], goals: { daily:[], weekly:[], monthly:[], quarterly:[] },
  activeTab: 'calendar',
  activeGoalType: 'daily',
  activeDomainFilter: 'all',
  calView: { year: new Date().getFullYear(), month: new Date().getMonth() },
  selectedDate: null,
  theme: 'dark',
  fontSize: 'md',
  editingTaskId: null,
  editingEventId: null,
  pomodoroActive: false, pomodoroSecs: 25*60, pomodoroInterval: null,
  importJson: null,
  miniCalState: {}   // per picker id: { year, month }
};

// ── Boot ────────────────────────────────────────────────────────────────────
async function boot() {

  // ADD THIS at the top of boot()
  const params = new URLSearchParams(window.location.search);
  if (params.get('mode') === 'web') {
    document.documentElement.classList.add('web-mode'); // ADD THIS
    document.body.classList.add('web-mode');
    
  }

  state.theme = await getTheme();
  const { profile, activeProfile, profiles } = await getActiveProfile();
  state.profile = profile; state.activeProfile = activeProfile; state.profiles = profiles;
  state.domains = profile.domains || [];
  state.tasks   = profile.tasks  || [];
  state.events  = profile.events || [];
  state.goals   = profile.goals  || { daily:[], weekly:[], monthly:[], quarterly:[] };
  state.fontSize = profile.settings?.fontSize || 'md';

  applyTheme(state.theme);
  applyFontSize(state.fontSize);
  initClock();
  bindNav();
  bindHeader();
  bindStats();
  bindCalendar();
  bindToday();
  bindGoals();
  bindDomains();
  bindSettings();
  bindModals();
  renderAll();
}

// ── Render All ──────────────────────────────────────────────────────────────
function renderAll() {
  renderHeader();
  renderStats();
  renderCalendar();
  renderTaskList();
  renderGoalsList();
  renderDomainsGrid();
  renderProfileManage();
  populateDomainSelects();
}

// ── Theme & Font ─────────────────────────────────────────────────────────────
function applyTheme(t) {
  // Remove only theme classes, preserve web-mode
  document.body.classList.remove('theme-dark', 'theme-light');
  document.body.classList.remove(...[...document.body.classList].filter(c => c.startsWith('font-')));
  document.body.classList.add('theme-' + t, 'font-' + state.fontSize);
  state.theme = t;
  const btn = document.getElementById('themeToggle');
  if (btn) btn.textContent = t === 'dark' ? '🌙' : '☀️';
  document.querySelectorAll('.theme-btn').forEach(b => {
    b.classList.toggle('active', b.dataset.theme === t);
  });
}

function applyFontSize(sz) {
  state.fontSize = sz;
  // Remove only font classes, preserve web-mode
  document.body.classList.remove(...[...document.body.classList].filter(c => c.startsWith('font-')));
  document.body.classList.add('font-' + sz);
  document.querySelectorAll('.size-btn').forEach(b => {
    b.classList.toggle('active', b.dataset.size === sz);
  });
}

// ── Clock ─────────────────────────────────────────────────────────────────
function initClock() {
  const tick = () => {
    const now = new Date();
    let h = now.getHours(), m = now.getMinutes(), s = now.getSeconds();
    const ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12 || 12;
    const pad = n => String(n).padStart(2,'0');
    document.getElementById('liveClock').textContent = `${pad(h)}:${pad(m)}:${pad(s)} ${ampm}`;
    const days = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    document.getElementById('liveDate').textContent =
      `${days[now.getDay()]}, ${pad(now.getDate())} ${months[now.getMonth()]} ${now.getFullYear()}`;
  };
  tick();
  setInterval(tick, 1000);
}

// ── Header ─────────────────────────────────────────────────────────────────
function renderHeader() {
  const p = state.profiles[state.activeProfile];
  document.getElementById('headerEmoji').textContent   = p?.emoji || '🎯';
  document.getElementById('headerProfileName').textContent = p?.name || 'Profile';

  const list = document.getElementById('profileList');
  list.innerHTML = '';
  for (const [id, prof] of Object.entries(state.profiles)) {
    const item = el('div', 'profile-item' + (id === state.activeProfile ? ' active' : ''));
    item.innerHTML = `<span class="p-dot" style="background:${prof.color}"></span>
      <span class="p-name">${prof.emoji || ''} ${prof.name}</span>
      ${id === state.activeProfile ? '<span class="p-check">✓</span>' : ''}`;
    item.addEventListener('click', async () => {
      await switchProfile(id);
      await reloadProfile();
      closeDropdown();
    });
    list.appendChild(item);
  }
}

function bindHeader() {
  document.getElementById('activeProfileBtn').addEventListener('click', e => {
    e.stopPropagation();
    document.getElementById('profileDropdown').classList.toggle('hidden');
  });
  document.addEventListener('click', () => closeDropdown());
  document.getElementById('themeToggle').addEventListener('click', async () => {
    const t = state.theme === 'dark' ? 'light' : 'dark';
    await setTheme(t); applyTheme(t);
  });
  document.getElementById('webModeBtn').addEventListener('click', () => {
    browser.tabs.create({ url: browser.runtime.getURL('popup/popup.html') + '?mode=web' });
  });
  document.getElementById('btnNewProfile').addEventListener('click', () => {
    closeDropdown(); openProfileModal();
  });
  document.getElementById('btnManageProfiles').addEventListener('click', () => {
    closeDropdown(); switchTab('settings');
  });
}

function closeDropdown() {
  document.getElementById('profileDropdown').classList.add('hidden');
}

// ── Stats ─────────────────────────────────────────────────────────────────
function renderStats() {
  const today = todayStr();
  const todayTasks = state.tasks.filter(t => {
    if (t.dueDate) return t.dueDate === today;
    return new Date(t.createdAt).toISOString().split('T')[0] === today;
  });
  const todayEvents = state.events.filter(e => e.date === today);
  const done = todayTasks.filter(t => t.completed).length;
  document.getElementById('streakCount').textContent = state.profile?.streaks?.current || 0;
  document.getElementById('todayDone').textContent   = done;
  document.getElementById('todayTotal').textContent  = todayTasks.length;
  document.getElementById('eventsToday').textContent = todayEvents.length;
}

function bindStats() {
  let running = false, breakMode = false;
  const pomoLen = () => (state.profile?.settings?.pomodoroLength || 25) * 60;
  const breakLen = () => (state.profile?.settings?.shortBreak || 5) * 60;
  state.pomodoroSecs = pomoLen();

  document.getElementById('pomoStart').addEventListener('click', () => {
    if (running) {
      clearInterval(state.pomodoroInterval);
      running = false;
      state.pomodoroSecs = breakMode ? breakLen() : pomoLen();
      breakMode = false;
      document.getElementById('pomoStart').textContent = '▶';
      renderPomoClock(state.pomodoroSecs);
    } else {
      running = true;
      document.getElementById('pomoStart').textContent = '⏸';
      state.pomodoroInterval = setInterval(() => {
        state.pomodoroSecs--;
        renderPomoClock(state.pomodoroSecs);
        if (state.pomodoroSecs <= 0) {
          clearInterval(state.pomodoroInterval);
          running = false;
          if (!breakMode) { breakMode = true; state.pomodoroSecs = breakLen(); toast('Pomodoro done! Take a break 🎉', 'success'); }
          else { breakMode = false; state.pomodoroSecs = pomoLen(); toast('Break over! Back to work 💪', 'info'); }
          document.getElementById('pomoStart').textContent = '▶';
          renderPomoClock(state.pomodoroSecs);
        }
      }, 1000);
    }
  });
}

function renderPomoClock(secs) {
  const m = String(Math.floor(secs/60)).padStart(2,'0');
  const s = String(secs%60).padStart(2,'0');
  document.getElementById('pomoClock').textContent = `${m}:${s}`;
}

// ── Nav ────────────────────────────────────────────────────────────────────
function bindNav() {
  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => switchTab(btn.dataset.tab));
  });
}

function switchTab(tab) {
  state.activeTab = tab;
  document.querySelectorAll('.tab-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
  document.querySelectorAll('.tab-pane').forEach(p => p.classList.toggle('active', p.id === 'tab-' + tab));
}

// ── Calendar ────────────────────────────────────────────────────────────────
function bindCalendar() {
  document.getElementById('calPrev').addEventListener('click', () => {
    let { year, month } = state.calView;
    month--; if (month < 0) { month = 11; year--; }
    state.calView = { year, month }; renderCalendar();
  });
  document.getElementById('calNext').addEventListener('click', () => {
    let { year, month } = state.calView;
    month++; if (month > 11) { month = 0; year++; }
    state.calView = { year, month }; renderCalendar();
  });
  document.getElementById('calToday').addEventListener('click', () => {
    const now = new Date();
    state.calView = { year: now.getFullYear(), month: now.getMonth() };
    state.selectedDate = todayStr();
    renderCalendar(); renderDayDetail(state.selectedDate);
  });
  document.getElementById('btnAddEvent').addEventListener('click', () => openEventModal(null, state.selectedDate));
  document.getElementById('btnAddEventDay').addEventListener('click', () => openEventModal(null, state.selectedDate));
}

function renderCalendar() {
  const { year, month } = state.calView;
  const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  document.getElementById('calMonthTitle').textContent = `${months[month]} ${year}`;

  const first = new Date(year, month, 1).getDay();
  const daysInMonth = new Date(year, month+1, 0).getDate();
  const daysInPrev  = new Date(year, month, 0).getDate();
  const today = todayStr();

  const grid = document.getElementById('calGrid');
  grid.innerHTML = '';

  const cells = 42;
  for (let i = 0; i < cells; i++) {
    const dayDiv = document.createElement('div');
    dayDiv.className = 'cal-day';

    let dayNum, dateStr, isOther = false;
    if (i < first) {
      dayNum = daysInPrev - first + 1 + i;
      dateStr = `${year}-${pad2(month === 0 ? 12 : month)}-${pad2(dayNum)}`;
      if (month === 0) dateStr = `${year-1}-12-${pad2(dayNum)}`;
      else dateStr = `${year}-${pad2(month)}-${pad2(dayNum)}`;
      isOther = true;
    } else if (i >= first + daysInMonth) {
      dayNum = i - first - daysInMonth + 1;
      dateStr = month === 11 ? `${year+1}-01-${pad2(dayNum)}` : `${year}-${pad2(month+2)}-${pad2(dayNum)}`;
      isOther = true;
    } else {
      dayNum = i - first + 1;
      dateStr = `${year}-${pad2(month+1)}-${pad2(dayNum)}`;
    }

    if (isOther) dayDiv.classList.add('other-month');
    if (dateStr === today) dayDiv.classList.add('today');
    if (dateStr === state.selectedDate) dayDiv.classList.add('selected');

    const numSpan = el('span', 'cal-day-num');
    numSpan.textContent = dayNum;
    dayDiv.appendChild(numSpan);

    // dots for events on this date
    const dayEvents = state.events.filter(e => e.date === dateStr);
    const dayTasks  = state.tasks.filter(t => t.dueDate === dateStr);
    const allItems = [...dayEvents, ...dayTasks];
    if (allItems.length) {
      const dots = el('div', 'cal-dots');
      const seen = new Set();
      allItems.forEach(item => {
        const domain = item.domain || 'dsa';
        if (!seen.has(domain)) {
          seen.add(domain);
          const dot = el('div', 'cal-dot');
          const d = state.domains.find(d => d.key === domain);
          dot.style.background = d?.color || '#8b949e';
          dots.appendChild(dot);
        }
      });
      dayDiv.appendChild(dots);
    }

    dayDiv.addEventListener('click', () => {
      state.selectedDate = dateStr;
      document.querySelectorAll('.cal-day').forEach(d => d.classList.remove('selected'));
      dayDiv.classList.add('selected');
      renderDayDetail(dateStr);
    });

    grid.appendChild(dayDiv);
  }

  // Render today's detail by default
  if (!state.selectedDate) {
    state.selectedDate = today;
    renderDayDetail(today);
  }
}

function renderDayDetail(dateStr) {
  if (!dateStr) return;
  const [y, m, d] = dateStr.split('-').map(Number);
  const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  document.getElementById('dayDetailTitle').textContent = `${months[m-1]} ${d}, ${y}`;

  const dayEvents = state.events.filter(e => e.date === dateStr);
  const dayTasks  = state.tasks.filter(t => t.dueDate === dateStr);
  const list = document.getElementById('dayEventsList');
  list.innerHTML = '';

  if (!dayEvents.length && !dayTasks.length) {
    list.innerHTML = '<div class="empty-mini">No events — click + Add to schedule something</div>';
    return;
  }

  // Combine and sort by time
  const items = [
    ...dayEvents.map(e => ({ ...e, _type: 'event' })),
    ...dayTasks.map(t => ({ ...t, _type: 'task' }))
  ].sort((a,b) => (a.startTime||'99:99').localeCompare(b.startTime||'99:99'));

  items.forEach(item => {
    const domain = state.domains.find(d => d.key === item.domain);
    const div = el('div', 'event-item' + (item.completed ? ' event-done' : ''));
    div.style.borderLeftColor = domain?.color || '#8b949e';

    const timeStr = item.allDay ? 'All day' : (item.startTime ? fmt12(item.startTime) : '—');
    div.innerHTML = `
      <span class="event-time">${timeStr}</span>
      <span class="event-title">${escHtml(item.title)}</span>
      <span class="event-tag">${domain?.icon||'📌'} ${domain?.label||item.domain}</span>
      <button class="btn-icon-sm" title="Edit">✏️</button>
      <button class="btn-icon-sm danger" title="Delete">🗑</button>
    `;
    div.querySelectorAll('.btn-icon-sm')[0].addEventListener('click', () => {
      if (item._type === 'event') openEventModal(item.id);
      else openTaskModal(item.id);
    });
    div.querySelectorAll('.btn-icon-sm')[1].addEventListener('click', async () => {
      if (item._type === 'event') { await deleteEvent(item.id); await reloadEvents(); }
      else { await deleteTask(item.id); await reloadTasks(); }
      renderCalendar(); renderDayDetail(dateStr); renderStats();
    });
    list.appendChild(div);
  });
}

// ── Today Tab ───────────────────────────────────────────────────────────────
function bindToday() {
  document.getElementById('btnAddTask').addEventListener('click', () => openTaskModal());

  document.getElementById('domainFilter').addEventListener('click', e => {
    const pill = e.target.closest('.pill');
    if (!pill) return;
    state.activeDomainFilter = pill.dataset.domain;
    document.querySelectorAll('#domainFilter .pill').forEach(p => {
      p.classList.toggle('active', p.dataset.domain === state.activeDomainFilter);
    });
    renderTaskList();
  });
}

function renderTaskList() {
  // Rebuild domain filter pills
  const filterEl = document.getElementById('domainFilter');
  filterEl.innerHTML = `<button class="pill ${state.activeDomainFilter==='all'?'active':''}" data-domain="all">All</button>`;
  state.domains.forEach(d => {
    const p = el('button', 'pill' + (state.activeDomainFilter===d.key?' active':''));
    p.dataset.domain = d.key;
    p.textContent = `${d.icon} ${d.label}`;
    filterEl.appendChild(p);
  });

  const list = document.getElementById('taskList');
  const filtered = state.activeDomainFilter === 'all'
    ? state.tasks
    : state.tasks.filter(t => t.domain === state.activeDomainFilter);

  if (!filtered.length) {
    list.innerHTML = '<div class="empty-state"><div>🎯</div><p>No tasks here yet — add one!</p></div>';
    return;
  }

  list.innerHTML = '';
  // Sort: incomplete first, then by priority
  const sorted = [...filtered].sort((a,b) => {
    if (a.completed !== b.completed) return a.completed ? 1 : -1;
    return (a.priority||'P2').localeCompare(b.priority||'P2');
  });

  sorted.forEach(task => {
    const domain = state.domains.find(d => d.key === task.domain);
    const card = el('div', 'task-card' + (task.completed?' completed':''));
    card.style.borderLeftColor = domain?.color || 'var(--border)';

    card.innerHTML = `
      <div class="task-header">
        <div class="task-check ${task.completed?'checked':''}">${task.completed?'✓':''}</div>
        <div class="task-info">
          <div class="task-title">${escHtml(task.title)}</div>
          <div class="task-meta">
            <span class="tag">${domain?.icon||'📌'} ${domain?.label||task.domain}</span>
            <span class="tag tag-priority-${task.priority}">${task.priority}</span>
            ${task.estimatedMins ? `<span class="tag">⏱ ${task.estimatedMins}m</span>` : ''}
            ${task.dueDate ? `<span class="tag">📅 ${formatDate(task.dueDate)}</span>` : ''}
          </div>
        </div>
        <div class="task-actions">
          <button class="btn-icon-sm" title="Edit">✏️</button>
          <button class="btn-icon-sm danger" title="Delete">🗑</button>
        </div>
      </div>
      ${task.description ? `<div style="font-size:0.78em;color:var(--text2);margin-top:6px;padding-left:28px">${escHtml(task.description)}</div>` : ''}
    `;

    card.querySelector('.task-check').addEventListener('click', async () => {
      await updateTask(task.id, { completed: !task.completed });
      await reloadTasks(); renderStats(); renderCalendar();
    });
    card.querySelectorAll('.btn-icon-sm')[0].addEventListener('click', () => openTaskModal(task.id));
    card.querySelectorAll('.btn-icon-sm')[1].addEventListener('click', async () => {
      await deleteTask(task.id); await reloadTasks(); renderStats(); renderCalendar();
    });
    list.appendChild(card);
  });
}

// ── Goals Tab ────────────────────────────────────────────────────────────────
function bindGoals() {
  document.getElementById('btnAddGoal').addEventListener('click', () => openGoalModal());
  document.querySelector('.goals-tabs').addEventListener('click', e => {
    const btn = e.target.closest('.goal-tab');
    if (!btn) return;
    state.activeGoalType = btn.dataset.goal;
    document.querySelectorAll('.goal-tab').forEach(b => b.classList.toggle('active', b.dataset.goal === state.activeGoalType));
    document.getElementById('goalTypeTitle').textContent = capitalize(state.activeGoalType) + ' Goals';
    renderGoalsList();
  });
}

function renderGoalsList() {
  const list = document.getElementById('goalsList');
  const goals = state.goals[state.activeGoalType] || [];
  if (!goals.length) {
    list.innerHTML = '<div class="empty-state"><div>🎯</div><p>No goals yet — set one!</p></div>';
    return;
  }
  list.innerHTML = '';
  goals.forEach(goal => {
    const domain = state.domains.find(d => d.key === goal.domain);
    const pct = Math.min(100, Math.round((goal.current / goal.target) * 100));
    const card = el('div', 'goal-card');
    card.innerHTML = `
      <div class="goal-header">
        <span class="goal-title">${escHtml(goal.title)}</span>
        <div style="display:flex;gap:4px">
          <button class="btn-icon-sm danger" title="Delete">🗑</button>
        </div>
      </div>
      <div class="goal-progress-bar"><div class="goal-bar-fill" style="width:${pct}%;background:${domain?.color||'var(--accent)'}"></div></div>
      <div class="goal-meta">
        <span>${domain?.icon||'📌'} ${domain?.label||'All'}</span>
        <span>${goal.current} / ${goal.target} ${goal.unit}</span>
        <span>${pct}%</span>
        ${goal.dueDate ? `<span>Due ${formatDate(goal.dueDate)}</span>` : ''}
      </div>
      <div style="display:flex;align-items:center;gap:8px;margin-top:8px">
        <input type="range" min="0" max="${goal.target}" value="${goal.current}" class="slider" style="flex:1">
        <span style="font-size:0.78em;color:var(--accent);font-family:var(--font-mono)">${goal.current}</span>
      </div>
    `;
    card.querySelector('input[type=range]').addEventListener('input', async e => {
      const val = +e.target.value;
      card.querySelector('.goal-meta span:nth-child(2)').textContent = `${val} / ${goal.target} ${goal.unit}`;
      card.querySelector('.goal-bar-fill').style.width = Math.min(100, Math.round(val/goal.target*100)) + '%';
      e.target.nextElementSibling.textContent = val;
      await updateGoalProgress(state.activeGoalType, goal.id, val);
      await reloadGoals();
    });
    card.querySelector('.btn-icon-sm').addEventListener('click', async () => {
      await deleteGoal(state.activeGoalType, goal.id); await reloadGoals();
    });
    list.appendChild(card);
  });
}

// ── Domains Tab ──────────────────────────────────────────────────────────────
function bindDomains() {
  document.getElementById('btnAddDomain').addEventListener('click', () => openDomainModal());
}

function renderDomainsGrid() {
  const grid = document.getElementById('domainsGrid');
  grid.innerHTML = '';
  const defaultKeys = ['dsa','java','spring','devops','articles'];
  state.domains.forEach(d => {
    const isDefault = defaultKeys.includes(d.key);
    const taskCount = state.tasks.filter(t => t.domain === d.key).length;
    const card = el('div', 'domain-card');
    card.style.borderLeftColor = d.color;
    card.innerHTML = `
      <span class="domain-icon">${d.icon}</span>
      <div class="domain-info">
        <div class="domain-label" style="color:${d.color}">${d.label}</div>
        <div class="domain-stats-txt">${taskCount} task${taskCount!==1?'s':''}</div>
      </div>
      ${isDefault ? '<span class="domain-default-badge">Default</span>' : ''}
      ${!isDefault ? '<button class="btn-icon-sm danger" title="Delete domain">🗑</button>' : ''}
    `;
    if (!isDefault) {
      card.querySelector('.btn-icon-sm').addEventListener('click', async () => {
        await deleteDomain(d.key); await reloadDomains();
      });
    }
    grid.appendChild(card);
  });
}

// ── Settings Tab ─────────────────────────────────────────────────────────────
function bindSettings() {
  document.querySelectorAll('.size-btn').forEach(btn => {
    btn.addEventListener('click', async () => {
      applyFontSize(btn.dataset.size);
      await saveActiveProfile({ settings: { ...state.profile.settings, fontSize: btn.dataset.size } });
    });
  });
  document.querySelectorAll('.theme-btn').forEach(btn => {
    btn.addEventListener('click', async () => { await setTheme(btn.dataset.theme); applyTheme(btn.dataset.theme); });
  });

  const dT = document.getElementById('dailyTarget');
  const dTV = document.getElementById('dailyTargetVal');
  dT.addEventListener('input', () => { dTV.textContent = dT.value + 'h'; });
  dT.addEventListener('change', async () => {
    await saveActiveProfile({ settings: { ...state.profile.settings, dailyTargetHours: +dT.value } });
  });

  const pL = document.getElementById('pomodoroLen');
  const pLV = document.getElementById('pomodoroLenVal');
  pL.addEventListener('input', () => { pLV.textContent = pL.value + 'm'; });

  const sB = document.getElementById('shortBreak');
  const sBV = document.getElementById('shortBreakVal');
  sB.addEventListener('input', () => { sBV.textContent = sB.value + 'm'; });
  sB.addEventListener('change', async () => {
    await saveActiveProfile({ settings: { ...state.profile.settings, shortBreak: +sB.value } });
  });

  document.getElementById('notifToggle').addEventListener('change', async e => {
    await saveActiveProfile({ settings: { ...state.profile.settings, notificationsEnabled: e.target.checked } });
  });

  document.getElementById('btnExportAll').addEventListener('click', async () => {
    const json = await exportAllProfiles();
    downloadJson(json, 'studyflow-all-profiles.json');
    toast('Exported successfully', 'success');
  });
  document.getElementById('btnExportCurrent').addEventListener('click', async () => {
    const json = JSON.stringify({ version:'2.0', singleProfile:true, exportedAt: new Date().toISOString(),
      profile: { ...state.profile, ...state.profiles[state.activeProfile] } }, null, 2);
    downloadJson(json, 'studyflow-profile.json');
    toast('Profile exported', 'success');
  });
  document.getElementById('btnImport').addEventListener('click', () => {
    document.getElementById('importFile').click();
  });
  document.getElementById('importFile').addEventListener('change', e => {
    const f = e.target.files[0]; if (!f) return;
    const reader = new FileReader();
    reader.onload = ev => {
      state.importJson = ev.target.result;
      document.getElementById('importInfo').textContent = `File: ${f.name}`;
      document.getElementById('importModal').classList.remove('hidden');
    };
    reader.readAsText(f);
  });
  document.getElementById('confirmImport').addEventListener('click', async () => {
    const mode = document.querySelector('input[name=importMode]:checked').value;
    try {
      await importData(state.importJson, mode);
      document.getElementById('importModal').classList.add('hidden');
      await reloadProfile(); toast('Import successful', 'success');
    } catch(e) { toast('Import failed: ' + e.message, 'error'); }
  });
  ['cancelImportModal','closeImportModal'].forEach(id => {
    document.getElementById(id).addEventListener('click', () => {
      document.getElementById('importModal').classList.add('hidden');
    });
  });
}

function renderProfileManage() {
  const list = document.getElementById('profileManageList');
  list.innerHTML = '';
  for (const [id, prof] of Object.entries(state.profiles)) {
    const item = el('div', 'profile-manage-item');
    item.innerHTML = `
      <span class="pm-dot" style="background:${prof.color}"></span>
      <span class="pm-name">${prof.emoji||''} ${prof.name}</span>
      <div class="pm-actions">
        ${id === state.activeProfile ? '<span style="font-size:0.78em;color:var(--accent)">Active</span>' : ''}
        <button class="btn-icon-sm" title="Switch">🔀</button>
        <button class="btn-icon-sm danger" title="Delete">🗑</button>
      </div>
    `;
    item.querySelectorAll('.btn-icon-sm')[0].addEventListener('click', async () => {
      await switchProfile(id); await reloadProfile();
    });
    item.querySelectorAll('.btn-icon-sm')[1].addEventListener('click', async () => {
      try {
        await deleteProfile(id); await reloadProfile();
        toast('Profile deleted', 'info');
      } catch(e) { toast(e.message, 'error'); }
    });
    list.appendChild(item);
  }
}

// ── Modals ─────────────────────────────────────────────────────────────────

// Event Modal
function openEventModal(id = null, preDate = null) {
  state.editingEventId = id;
  const existing = id ? state.events.find(e => e.id === id) : null;
  document.getElementById('eventModalTitle').textContent = id ? 'Edit Event' : 'Add Event';

  document.getElementById('evTitle').value = existing?.title || '';
  document.getElementById('evDesc').value  = existing?.description || '';
  document.getElementById('evType').value  = existing?.type || 'task';
  document.getElementById('evPriority').value = existing?.priority || 'P2';

  populateDomainSelect(document.getElementById('evDomain'), existing?.domain || state.domains[0]?.key);

  const evDate = existing?.date || preDate || todayStr();
  setDatePickerValue('evDate', 'evDateDisplay', 'evMiniCal', evDate);

  const allDay = existing ? existing.allDay : true;
  document.getElementById('evAllDay').checked = allDay;
  document.getElementById('evTimeRow').style.display = allDay ? 'none' : '';

  if (existing?.startTime) setTimePicker('evStartHr','evStartMin','evStartAmPm', existing.startTime);
  else setTimePicker('evStartHr','evStartMin','evStartAmPm', '09:00');
  if (existing?.endTime) setTimePicker('evEndHr','evEndMin','evEndAmPm', existing.endTime);
  else setTimePicker('evEndHr','evEndMin','evEndAmPm', '10:00');

  document.getElementById('evAllDay').onchange = e => {
    document.getElementById('evTimeRow').style.display = e.target.checked ? 'none' : '';
  };

  document.getElementById('eventModal').classList.remove('hidden');
}

document.addEventListener('DOMContentLoaded', () => {}); // placeholder

function bindModals() {
  // Close buttons
  [['closeEventModal','eventModal'],['cancelEventModal','eventModal'],
   ['closeTaskModal','taskModal'],  ['cancelTaskModal','taskModal'],
   ['closeGoalModal','goalModal'],  ['cancelGoalModal','goalModal'],
   ['closeDomainModal','domainModal'],['cancelDomainModal','domainModal'],
   ['closeProfileModal','profileModal'],['cancelProfileModal','profileModal']
  ].forEach(([btnId, modalId]) => {
    const btn = document.getElementById(btnId);
    if (btn) btn.addEventListener('click', () => document.getElementById(modalId).classList.add('hidden'));
  });

  // Close on overlay click
  document.querySelectorAll('.modal-overlay').forEach(overlay => {
    overlay.addEventListener('click', e => {
      if (e.target === overlay) overlay.classList.add('hidden');
    });
  });

  // Save Event
  document.getElementById('saveEventModal').addEventListener('click', async () => {
    const title = document.getElementById('evTitle').value.trim();
    if (!title) { toast('Please enter a title', 'error'); return; }
    const allDay = document.getElementById('evAllDay').checked;
    const data = {
      title,
      description: document.getElementById('evDesc').value.trim(),
      domain: document.getElementById('evDomain').value,
      type: document.getElementById('evType').value,
      priority: document.getElementById('evPriority').value,
      date: document.getElementById('evDate').value || todayStr(),
      allDay,
      startTime: allDay ? null : getTimePicker('evStartHr','evStartMin','evStartAmPm'),
      endTime:   allDay ? null : getTimePicker('evEndHr','evEndMin','evEndAmPm')
    };
    if (state.editingEventId) await updateEvent(state.editingEventId, data);
    else await addEvent(data);
    document.getElementById('eventModal').classList.add('hidden');
    await reloadEvents(); renderCalendar(); renderDayDetail(state.selectedDate); renderStats();
    toast(state.editingEventId ? 'Event updated' : 'Event added', 'success');
  });

  // Save Task
  document.getElementById('saveTaskModal').addEventListener('click', async () => {
    const title = document.getElementById('taskTitle').value.trim();
    if (!title) { toast('Please enter a title', 'error'); return; }
    const notifyDateVal = document.getElementById('notifyDate').value;
    const notifyTimeVal = getTimePicker('notifyHr','notifyMin','notifyAmPm');
    const notifyAt = notifyDateVal && notifyTimeVal
      ? new Date(`${notifyDateVal}T${notifyTimeVal}`).getTime() : null;
    const data = {
      title,
      description: document.getElementById('taskDesc').value.trim(),
      domain: document.getElementById('taskDomain').value,
      priority: document.getElementById('taskPriority').value,
      estimatedMins: +document.getElementById('taskEstTime').value || 30,
      goalType: document.getElementById('taskGoalType').value,
      dueDate: document.getElementById('taskDueDate').value || null,
      notifyAt
    };
    if (state.editingTaskId) await updateTask(state.editingTaskId, data);
    else await addTask(data);
    document.getElementById('taskModal').classList.add('hidden');
    await reloadTasks(); renderCalendar(); if (state.selectedDate) renderDayDetail(state.selectedDate); renderStats();
    toast(state.editingTaskId ? 'Task updated' : 'Task added', 'success');
  });

  // Save Goal
  document.getElementById('saveGoalModal').addEventListener('click', async () => {
    const title = document.getElementById('goalTitle').value.trim();
    if (!title) { toast('Please enter a title', 'error'); return; }
    const data = {
      title,
      domain: document.getElementById('goalDomain').value,
      target: +document.getElementById('goalTarget').value || 1,
      unit: document.getElementById('goalUnit').value || 'tasks',
      dueDate: document.getElementById('goalDueDate').value || null
    };
    await addGoal(state.activeGoalType, data);
    document.getElementById('goalModal').classList.add('hidden');
    await reloadGoals(); toast('Goal added', 'success');
  });

  // Save Domain
  document.getElementById('saveDomainModal').addEventListener('click', async () => {
    const name = document.getElementById('domainName').value.trim();
    if (!name) { toast('Please enter a domain name', 'error'); return; }
    const selIcon  = document.querySelector('#iconPicker .icon-opt.selected');
    const selColor = document.querySelector('#colorPicker .color-opt.selected');
    await addDomain({
      label: name,
      icon: selIcon?.textContent || '📚',
      color: selColor?.dataset.color || '#8b5cf6'
    });
    document.getElementById('domainModal').classList.add('hidden');
    await reloadDomains(); toast('Domain added', 'success');
  });

  // Save Profile
  document.getElementById('saveProfileModal').addEventListener('click', async () => {
    const name = document.getElementById('profileName').value.trim();
    if (!name) { toast('Please enter a profile name', 'error'); return; }
    const selEmoji = document.querySelector('#emojiPicker .icon-opt.selected');
    const selColor = document.querySelector('#profileColorPicker .color-opt.selected');
    const id = await createProfile(name, selColor?.dataset.color || '#10b981', selEmoji?.textContent || '🎯');
    await switchProfile(id);
    document.getElementById('profileModal').classList.add('hidden');
    await reloadProfile(); toast('Profile created', 'success');
  });

  // Time selects population
  ['evStartHr','evEndHr','notifyHr'].forEach(id => populateHours(id));
  ['evStartMin','evEndMin','notifyMin'].forEach(id => populateMins(id));
  ['evStartAmPm','evEndAmPm','notifyAmPm'].forEach(id => populateAmPm(id));

  // Date pickers
  initDatePicker('evDatePicker', 'evDate', 'evDateDisplay', 'evMiniCal');
  initDatePicker('taskDatePicker', 'taskDueDate', 'taskDateDisplay', 'taskMiniCal');
  initDatePicker('notifyDatePicker', 'notifyDate', 'notifyDateDisplay', 'notifyMiniCal');
  initDatePicker('goalDatePicker', 'goalDueDate', 'goalDateDisplay', 'goalMiniCal');
}

function openTaskModal(id = null) {
  state.editingTaskId = id;
  const existing = id ? state.tasks.find(t => t.id === id) : null;
  document.getElementById('taskModalTitle').textContent = id ? 'Edit Task' : 'Add Task';
  document.getElementById('taskTitle').value       = existing?.title || '';
  document.getElementById('taskDesc').value        = existing?.description || '';
  document.getElementById('taskEstTime').value     = existing?.estimatedMins || 30;
  document.getElementById('taskGoalType').value    = existing?.goalType || 'daily';
  document.getElementById('taskPriority').value    = existing?.priority || 'P2';
  populateDomainSelect(document.getElementById('taskDomain'), existing?.domain || state.domains[0]?.key);
  setDatePickerValue('taskDueDate', 'taskDateDisplay', 'taskMiniCal', existing?.dueDate || null);
  document.getElementById('taskModal').classList.remove('hidden');
}

function openGoalModal() {
  document.getElementById('goalTitle').value  = '';
  document.getElementById('goalTarget').value = 1;
  document.getElementById('goalUnit').value   = 'tasks';
  populateDomainSelect(document.getElementById('goalDomain'), 'all', true);
  setDatePickerValue('goalDueDate', 'goalDateDisplay', 'goalMiniCal', null);
  document.getElementById('goalModal').classList.remove('hidden');
}

function openDomainModal() {
  document.getElementById('domainName').value = '';
  buildIconPicker('iconPicker', DOMAIN_ICONS, null);
  buildColorPicker('colorPicker', DOMAIN_COLORS, null);
  document.getElementById('domainModal').classList.remove('hidden');
}

function openProfileModal() {
  document.getElementById('profileName').value = '';
  buildIconPicker('emojiPicker', PROFILE_EMOJIS, null);
  buildColorPicker('profileColorPicker', PROFILE_COLORS, null);
  document.getElementById('profileModal').classList.remove('hidden');
}

// ── Date Picker ─────────────────────────────────────────────────────────────
function initDatePicker(wrapId, hiddenId, displayId, calId) {
  const wrap = document.getElementById(wrapId);
  if (!wrap) return;
  const display = document.getElementById(displayId);
  const cal = document.getElementById(calId);
  const now = new Date();
  state.miniCalState[calId] = { year: now.getFullYear(), month: now.getMonth() };

  display.addEventListener('click', e => {
    e.stopPropagation();
    // Close all other mini cals
    document.querySelectorAll('.mini-cal').forEach(c => { if (c.id !== calId) c.classList.add('hidden'); });
    cal.classList.toggle('hidden');
    if (!cal.classList.contains('hidden')) renderMiniCal(hiddenId, displayId, calId);
  });
  document.addEventListener('click', e => {
    if (!wrap.contains(e.target)) cal.classList.add('hidden');
  });
}

function renderMiniCal(hiddenId, displayId, calId) {
  const cal = document.getElementById(calId);
  const { year, month } = state.miniCalState[calId];
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  const today = todayStr();
  const selected = document.getElementById(hiddenId).value;
  const first = new Date(year, month, 1).getDay();
  const daysInMonth = new Date(year, month+1, 0).getDate();
  const daysInPrev  = new Date(year, month, 0).getDate();

  cal.innerHTML = `
    <div class="mc-header">
      <button class="mc-nav" data-dir="-1">‹</button>
      <span class="mc-title">${months[month]} ${year}</span>
      <button class="mc-nav" data-dir="1">›</button>
    </div>
    <div class="mc-days-header">
      <span>Su</span><span>Mo</span><span>Tu</span><span>We</span><span>Th</span><span>Fr</span><span>Sa</span>
    </div>
    <div class="mc-grid" id="${calId}-grid"></div>
  `;

  cal.querySelectorAll('.mc-nav').forEach(btn => {
    btn.addEventListener('click', e => {
      e.stopPropagation();
      let { year: y, month: m } = state.miniCalState[calId];
      m += +btn.dataset.dir;
      if (m < 0) { m = 11; y--; } else if (m > 11) { m = 0; y++; }
      state.miniCalState[calId] = { year: y, month: m };
      renderMiniCal(hiddenId, displayId, calId);
    });
  });

  const grid = document.getElementById(calId + '-grid');
  const cells = 42;
  for (let i = 0; i < cells; i++) {
    let dayNum, dateStr, isOther = false;
    if (i < first) {
      dayNum = daysInPrev - first + 1 + i;
      dateStr = month === 0 ? `${year-1}-12-${pad2(dayNum)}` : `${year}-${pad2(month)}-${pad2(dayNum)}`;
      isOther = true;
    } else if (i >= first + daysInMonth) {
      dayNum = i - first - daysInMonth + 1;
      dateStr = month === 11 ? `${year+1}-01-${pad2(dayNum)}` : `${year}-${pad2(month+2)}-${pad2(dayNum)}`;
      isOther = true;
    } else {
      dayNum = i - first + 1;
      dateStr = `${year}-${pad2(month+1)}-${pad2(dayNum)}`;
    }
    const cell = el('div', 'mc-cell' + (isOther?' other':'') + (dateStr===today?' today':'') + (dateStr===selected?' selected':''));
    cell.textContent = dayNum;
    cell.addEventListener('click', e => {
      e.stopPropagation();
      document.getElementById(hiddenId).value = dateStr;
      document.getElementById(displayId).textContent = formatDate(dateStr);
      cal.classList.add('hidden');
    });
    grid.appendChild(cell);
  }
}

function setDatePickerValue(hiddenId, displayId, calId, value) {
  const h = document.getElementById(hiddenId);
  const d = document.getElementById(displayId);
  if (!h || !d) return;
  h.value = value || '';
  d.textContent = value ? formatDate(value) : 'Select Date';
  if (value) {
    const [y,m] = value.split('-').map(Number);
    if (state.miniCalState[calId]) state.miniCalState[calId] = { year: y, month: m-1 };
  }
}

// ── Time Picker ─────────────────────────────────────────────────────────────
function populateHours(id) {
  const sel = document.getElementById(id); if (!sel) return;
  sel.innerHTML = '';
  for (let h = 1; h <= 12; h++) {
    const o = document.createElement('option');
    o.value = String(h); o.textContent = String(h).padStart(2,'0');
    sel.appendChild(o);
  }
}
function populateMins(id) {
  const sel = document.getElementById(id); if (!sel) return;
  sel.innerHTML = '';
  for (let m = 0; m < 60; m += 15) {
    const o = document.createElement('option');
    o.value = String(m).padStart(2,'0'); o.textContent = String(m).padStart(2,'0');
    sel.appendChild(o);
  }
}
function populateAmPm(id) {
  const sel = document.getElementById(id); if (!sel) return;
  sel.innerHTML = '<option value="AM">AM</option><option value="PM">PM</option>';
}

function setTimePicker(hrId, minId, ampmId, time24) {
  // time24 = 'HH:MM' in 24h
  const [hh, mm] = (time24||'09:00').split(':').map(Number);
  const ampm = hh >= 12 ? 'PM' : 'AM';
  const h12 = hh % 12 || 12;
  const minRounded = Math.round(mm / 15) * 15 % 60;
  const hrEl = document.getElementById(hrId);
  const minEl = document.getElementById(minId);
  const amEl  = document.getElementById(ampmId);
  if (hrEl) hrEl.value = String(h12);
  if (minEl) minEl.value = String(minRounded).padStart(2,'0');
  if (amEl)  amEl.value = ampm;
}

function getTimePicker(hrId, minId, ampmId) {
  const h = +(document.getElementById(hrId)?.value || 9);
  const m = document.getElementById(minId)?.value || '00';
  const ap = document.getElementById(ampmId)?.value || 'AM';
  let h24 = h % 12 + (ap === 'PM' ? 12 : 0);
  return `${pad2(h24)}:${m}`;
}

// ── Pickers ─────────────────────────────────────────────────────────────────
function buildIconPicker(id, icons, selected) {
  const wrap = document.getElementById(id); if (!wrap) return;
  wrap.innerHTML = '';
  icons.forEach((ic, i) => {
    const opt = el('div', 'icon-opt' + (i === 0 ? ' selected' : ''));
    opt.textContent = ic;
    opt.addEventListener('click', () => {
      wrap.querySelectorAll('.icon-opt').forEach(o => o.classList.remove('selected'));
      opt.classList.add('selected');
    });
    wrap.appendChild(opt);
  });
}

function buildColorPicker(id, colors, selected) {
  const wrap = document.getElementById(id); if (!wrap) return;
  wrap.innerHTML = '';
  colors.forEach((c, i) => {
    const opt = el('div', 'color-opt' + (i === 0 ? ' selected' : ''));
    opt.style.background = c; opt.dataset.color = c;
    opt.addEventListener('click', () => {
      wrap.querySelectorAll('.color-opt').forEach(o => o.classList.remove('selected'));
      opt.classList.add('selected');
    });
    wrap.appendChild(opt);
  });
}

function populateDomainSelects() {
  document.querySelectorAll('select[id$="Domain"]').forEach(sel => {
    const cur = sel.value;
    const needAll = sel.id === 'goalDomain';
    populateDomainSelect(sel, cur, needAll);
  });
}

function populateDomainSelect(sel, selected, includeAll = false) {
  if (!sel) return;
  sel.innerHTML = '';
  if (includeAll) {
    const o = document.createElement('option');
    o.value = 'all'; o.textContent = '🌐 All Domains';
    sel.appendChild(o);
  }
  state.domains.forEach(d => {
    const o = document.createElement('option');
    o.value = d.key; o.textContent = `${d.icon} ${d.label}`;
    if (d.key === selected) o.selected = true;
    sel.appendChild(o);
  });
  if (selected === 'all' && includeAll) sel.value = 'all';
}

// ── Reload helpers ──────────────────────────────────────────────────────────
async function reloadProfile() {
  const { profile, activeProfile, profiles } = await getActiveProfile();
  state.profile = profile; state.activeProfile = activeProfile; state.profiles = profiles;
  state.domains = profile.domains || [];
  state.tasks   = profile.tasks  || [];
  state.events  = profile.events || [];
  state.goals   = profile.goals  || { daily:[], weekly:[], monthly:[], quarterly:[] };
  renderAll();
}
async function reloadTasks() {
  state.tasks = await getTasks(); renderTaskList();
}
async function reloadEvents() {
  state.events = await getEvents();
}
async function reloadGoals() {
  state.goals = await getGoals(); renderGoalsList();
}
async function reloadDomains() {
  state.domains = await getDomains();
  renderDomainsGrid(); populateDomainSelects();
}

// ── Utils ───────────────────────────────────────────────────────────────────
function el(tag, cls) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  return e;
}
function pad2(n) { return String(n).padStart(2,'0'); }
function todayStr() { return new Date().toISOString().split('T')[0]; }
function formatDate(str) {
  if (!str) return '';
  const [y,m,d] = str.split('-').map(Number);
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return `${months[m-1]} ${d}, ${y}`;
}
function fmt12(time24) {
  const [h,m] = time24.split(':').map(Number);
  const ap = h >= 12 ? 'PM' : 'AM';
  return `${h%12||12}:${pad2(m)} ${ap}`;
}
function capitalize(s) { return s.charAt(0).toUpperCase() + s.slice(1); }
function escHtml(s) { return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }

let toastTimer;
function toast(msg, type = 'info') {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.className = `toast ${type}`;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.add('hidden'), 3000);
}

function downloadJson(json, filename) {
  const blob = new Blob([json], { type: 'application/json' });
  const url  = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = filename; a.click();
  URL.revokeObjectURL(url);
}

// ── Start ───────────────────────────────────────────────────────────────────
boot().catch(console.error);