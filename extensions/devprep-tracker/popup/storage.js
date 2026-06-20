// storage.js — StudyFlow Tracker Data Layer

export const DEFAULT_SETTINGS = {
  dailyTargetHours: 6,
  notificationsEnabled: true,
  pomodoroLength: 25,
  shortBreak: 5,
  longBreak: 15,
  theme: 'dark',
  fontSize: 'md',   // sm | md | lg | xl
  appMode: 'popup'  // popup | web
};

export const DEFAULT_DOMAINS = [
  { key: 'dsa',      label: 'DSA',         icon: '🧩', color: '#f59e0b' },
  { key: 'java',     label: 'Core Java',   icon: '☕', color: '#ef4444' },
  { key: 'spring',   label: 'Spring Boot', icon: '🌱', color: '#10b981' },
  { key: 'devops',   label: 'DevOps',      icon: '⚙️', color: '#3b82f6' },
  { key: 'articles', label: 'Articles',    icon: '📰', color: '#8b5cf6' }
];

export const PROFILE_COLORS = ['#10b981','#3b82f6','#f59e0b','#ef4444','#8b5cf6','#ec4899','#06b6d4','#84cc16'];
export const PROFILE_EMOJIS = ['☕','🧩','🌱','⚙️','🎯','📚','💻','🚀','🔥','💡'];
export const DOMAIN_ICONS   = ['🧩','☕','🌱','⚙️','📰','🎯','💻','🚀','🔥','💡','📐','🔬','🗄️','🌐','📊'];
export const DOMAIN_COLORS  = ['#f59e0b','#ef4444','#10b981','#3b82f6','#8b5cf6','#ec4899','#06b6d4','#84cc16','#f97316','#a855f7'];

export const DEFAULT_PROFILE = () => ({
  tasks: [],
  events: [],   // calendar events
  goals: { daily: [], weekly: [], monthly: [], quarterly: [] },
  sessions: [],
  streaks: { current: 0, longest: 0, lastStudyDate: null },
  settings: { ...DEFAULT_SETTINGS },
  domains: JSON.parse(JSON.stringify(DEFAULT_DOMAINS)),
  createdAt: Date.now()
});

export function generateId() {
  return 'id-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9);
}

// ── Storage primitives ──────────────────────────────────────────────────────

export async function getStorage(keys) { return browser.storage.local.get(keys); }
export async function setStorage(data) { return browser.storage.local.set(data); }

// ── Profile helpers ─────────────────────────────────────────────────────────

export async function getAllProfiles() {
  const data = await getStorage(['profiles', 'activeProfile']);
  let profiles = data.profiles || {};
  let activeProfile = data.activeProfile;
  if (Object.keys(profiles).length === 0) {
    const id = 'default-profile';
    profiles[id] = { ...DEFAULT_PROFILE(), name: 'My Study Plan', color: '#10b981', emoji: '🎯' };
    activeProfile = id;
    await setStorage({ profiles, activeProfile });
  }
  return { profiles, activeProfile };
}

export async function getActiveProfile() {
  const { profiles, activeProfile } = await getAllProfiles();
  return { profile: profiles[activeProfile], activeProfile, profiles };
}

export async function saveActiveProfile(profileData) {
  const { profiles, activeProfile } = await getAllProfiles();
  profiles[activeProfile] = { ...profiles[activeProfile], ...profileData };
  await setStorage({ profiles });
}

export async function createProfile(name, color, emoji) {
  const { profiles } = await getAllProfiles();
  const id = 'profile-' + Date.now();
  profiles[id] = { ...DEFAULT_PROFILE(), name, color, emoji };
  await setStorage({ profiles });
  return id;
}

export async function deleteProfile(id) {
  const { profiles, activeProfile } = await getAllProfiles();
  if (Object.keys(profiles).length <= 1) throw new Error('Cannot delete the only profile');
  delete profiles[id];
  let newActive = activeProfile === id ? Object.keys(profiles)[0] : activeProfile;
  await setStorage({ profiles, activeProfile: newActive });
  return newActive;
}

export async function switchProfile(id) { await setStorage({ activeProfile: id }); }

export async function renameProfile(id, newName) {
  const { profiles } = await getAllProfiles();
  profiles[id].name = newName;
  await setStorage({ profiles });
}

// ── Domain helpers ──────────────────────────────────────────────────────────

export async function getDomains() {
  const { profile } = await getActiveProfile();
  return profile.domains || JSON.parse(JSON.stringify(DEFAULT_DOMAINS));
}

export async function saveDomains(domains) { await saveActiveProfile({ domains }); }

export async function addDomain(domainData) {
  const domains = await getDomains();
  const d = {
    key: 'custom-' + Date.now(),
    label: domainData.label,
    icon: domainData.icon || '📚',
    color: domainData.color || '#8b5cf6'
  };
  domains.push(d);
  await saveDomains(domains);
  return d;
}

export async function deleteDomain(key) {
  const domains = await getDomains();
  await saveDomains(domains.filter(d => d.key !== key));
}

// ── Task helpers ────────────────────────────────────────────────────────────

export async function getTasks() {
  const { profile } = await getActiveProfile();
  return profile.tasks || [];
}

export async function saveTasks(tasks) { await saveActiveProfile({ tasks }); }

export async function addTask(taskData) {
  const tasks = await getTasks();
  const task = {
    id: generateId(),
    title: taskData.title || 'Untitled Task',
    description: taskData.description || '',
    domain: taskData.domain || 'dsa',
    priority: taskData.priority || 'P2',
    estimatedMins: taskData.estimatedMins || 30,
    actualMins: 0,
    subtasks: [],
    completed: false,
    notifyAt: taskData.notifyAt || null,
    dueDate: taskData.dueDate || null,
    createdAt: Date.now(),
    completedAt: null,
    goalType: taskData.goalType || 'daily',
    tags: taskData.tags || []
  };
  tasks.push(task);
  await saveTasks(tasks);
  return task;
}

export async function updateTask(taskId, updates) {
  const tasks = await getTasks();
  const idx = tasks.findIndex(t => t.id === taskId);
  if (idx === -1) return;
  tasks[idx] = { ...tasks[idx], ...updates };
  if (updates.completed && !tasks[idx].completedAt) tasks[idx].completedAt = Date.now();
  await saveTasks(tasks);
  return tasks[idx];
}

export async function deleteTask(taskId) {
  const tasks = await getTasks();
  await saveTasks(tasks.filter(t => t.id !== taskId));
}

// ── Calendar Event helpers ──────────────────────────────────────────────────

export async function getEvents() {
  const { profile } = await getActiveProfile();
  return profile.events || [];
}

export async function saveEvents(events) { await saveActiveProfile({ events }); }

export async function addEvent(eventData) {
  const events = await getEvents();
  const ev = {
    id: generateId(),
    title: eventData.title || 'Untitled',
    description: eventData.description || '',
    domain: eventData.domain || 'dsa',
    date: eventData.date,           // 'YYYY-MM-DD'
    startTime: eventData.startTime || null,  // 'HH:MM'
    endTime: eventData.endTime || null,
    allDay: eventData.allDay !== false,
    type: eventData.type || 'task', // task | goal | reminder | session
    completed: false,
    color: eventData.color || null,
    createdAt: Date.now()
  };
  events.push(ev);
  await saveEvents(events);
  return ev;
}

export async function updateEvent(id, updates) {
  const events = await getEvents();
  const idx = events.findIndex(e => e.id === id);
  if (idx === -1) return;
  events[idx] = { ...events[idx], ...updates };
  await saveEvents(events);
  return events[idx];
}

export async function deleteEvent(id) {
  const events = await getEvents();
  await saveEvents(events.filter(e => e.id !== id));
}

// ── Goals helpers ───────────────────────────────────────────────────────────

export async function getGoals() {
  const { profile } = await getActiveProfile();
  return profile.goals || { daily: [], weekly: [], monthly: [], quarterly: [] };
}

export async function saveGoals(goals) { await saveActiveProfile({ goals }); }

export async function addGoal(type, goalData) {
  const goals = await getGoals();
  const goal = {
    id: generateId(),
    title: goalData.title,
    domain: goalData.domain || 'all',
    target: goalData.target || 1,
    current: 0,
    unit: goalData.unit || 'tasks',
    completed: false,
    createdAt: Date.now(),
    dueDate: goalData.dueDate || null
  };
  goals[type].push(goal);
  await saveGoals(goals);
  return goal;
}

export async function updateGoalProgress(type, goalId, current) {
  const goals = await getGoals();
  const goal = goals[type].find(g => g.id === goalId);
  if (!goal) return;
  goal.current = current;
  goal.completed = current >= goal.target;
  await saveGoals(goals);
}

export async function deleteGoal(type, goalId) {
  const goals = await getGoals();
  goals[type] = goals[type].filter(g => g.id !== goalId);
  await saveGoals(goals);
}

// ── Session helpers ─────────────────────────────────────────────────────────

export async function logSession(domain, minutes) {
  const { profile } = await getActiveProfile();
  const sessions = profile.sessions || [];
  const today = new Date().toISOString().split('T')[0];
  sessions.push({ date: today, domain, minutes, timestamp: Date.now() });
  const streaks = profile.streaks || { current: 0, longest: 0, lastStudyDate: null };
  if (streaks.lastStudyDate !== today) {
    const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];
    streaks.current = streaks.lastStudyDate === yesterday ? streaks.current + 1 : 1;
    streaks.longest = Math.max(streaks.longest, streaks.current);
    streaks.lastStudyDate = today;
  }
  await saveActiveProfile({ sessions, streaks });
}

// ── Export / Import ─────────────────────────────────────────────────────────

export async function exportAllProfiles() {
  const { profiles, activeProfile } = await getAllProfiles();
  return JSON.stringify({ version: '2.0', exportedAt: new Date().toISOString(), activeProfile, profiles }, null, 2);
}

export async function importData(jsonString, mode = 'merge') {
  const imp = JSON.parse(jsonString);
  const { profiles: cur } = await getAllProfiles();
  if (imp.singleProfile) {
    if (mode === 'overwrite') {
      const { activeProfile } = await getAllProfiles();
      cur[activeProfile] = imp.profile;
    } else {
      cur['imported-' + Date.now()] = { ...imp.profile, name: (imp.profile.name || 'Imported') + ' (Imported)' };
    }
  } else {
    if (mode === 'overwrite') { await setStorage({ profiles: imp.profiles, activeProfile: imp.activeProfile }); return; }
    for (const [k, v] of Object.entries(imp.profiles)) {
      cur['imp-' + k + '-' + Date.now()] = { ...v, name: (v.name || k) + ' (Imported)' };
    }
  }
  await setStorage({ profiles: cur });
}

export async function getTheme() {
  const data = await getStorage('globalTheme');
  return data.globalTheme || 'dark';
}
export async function setTheme(theme) { await setStorage({ globalTheme: theme }); }