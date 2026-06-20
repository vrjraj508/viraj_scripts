
# mainfest.json

```
{

  "manifest_version": 3,

  "name": "DevPrep Tracker",

  "version": "1.0.0",

  "description": "Java/Spring Boot Interview Prep Planner — DSA, Core Java, Spring Boot, DevOps, Articles",

  "icons": {

    "48": "icons/icon48.png",

    "96": "icons/icon96.png"

  },

  "action": {

    "default_popup": "popup/popup.html",

    "default_icon": {

      "48": "icons/icon48.png"

    },

    "default_title": "DevPrep Tracker"

  },

  "background": {

    "scripts": ["background/background.js"],

    "type": "module"

  },

  "permissions": [

    "storage",

    "alarms",

    "notifications",

    "unlimitedStorage"

  ],

  "browser_specific_settings": {

    "gecko": {

      "id": "devprep-tracker@viraj.dev",

      "strict_min_version": "109.0"

    }

  }

}

```


# storage.js 

```
// storage.js — Core data layer for DevPrep Tracker

  

export const DEFAULT_SETTINGS = {

  dailyTargetHours: 6,

  notificationsEnabled: true,

  pomodoroLength: 25,

  shortBreak: 5,

  longBreak: 15,

  theme: 'dark'

};

  

export const DEFAULT_PROFILE = () => ({

  tasks: [],

  goals: { daily: [], weekly: [], monthly: [], quarterly: [] },

  sessions: [],

  streaks: { current: 0, longest: 0, lastStudyDate: null },

  settings: { ...DEFAULT_SETTINGS },

  createdAt: Date.now()

});

  

export const DOMAINS = [

  { key: 'dsa',      label: 'DSA',         icon: '🧩', color: '#f59e0b' },

  { key: 'java',     label: 'Core Java',   icon: '☕', color: '#ef4444' },

  { key: 'spring',   label: 'Spring Boot', icon: '🌱', color: '#10b981' },

  { key: 'devops',   label: 'DevOps',      icon: '⚙️', color: '#3b82f6' },

  { key: 'articles', label: 'Articles',    icon: '📰', color: '#8b5cf6' }

];

  

export const PROFILE_COLORS = [

  '#10b981','#3b82f6','#f59e0b','#ef4444','#8b5cf6','#ec4899','#06b6d4','#84cc16'

];

  

export const PROFILE_EMOJIS = ['☕','🧩','🌱','⚙️','🎯','📚','💻','🚀','🔥','💡'];

  

// ── Storage helpers ──────────────────────────────────────────────────────────

  

export async function getStorage(keys) {

  return browser.storage.local.get(keys);

}

  

export async function setStorage(data) {

  return browser.storage.local.set(data);

}

  

// ── Profile helpers ──────────────────────────────────────────────────────────

  

export async function getAllProfiles() {

  const data = await getStorage(['profiles', 'activeProfile']);

  let profiles = data.profiles || {};

  let activeProfile = data.activeProfile;

  

  // Bootstrap first run

  if (Object.keys(profiles).length === 0) {

    const id = 'java-sde2-prep';

    profiles[id] = { ...DEFAULT_PROFILE(), name: 'Java SDE-2 Prep', color: '#10b981', emoji: '☕' };

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

  let newActive = activeProfile;

  if (activeProfile === id) newActive = Object.keys(profiles)[0];

  await setStorage({ profiles, activeProfile: newActive });

  return newActive;

}

  

export async function switchProfile(id) {

  await setStorage({ activeProfile: id });

}

  

export async function duplicateProfile(id) {

  const { profiles } = await getAllProfiles();

  const source = profiles[id];

  const newId = 'profile-' + Date.now();

  profiles[newId] = JSON.parse(JSON.stringify(source));

  profiles[newId].name = source.name + ' (Copy)';

  profiles[newId].createdAt = Date.now();

  await setStorage({ profiles });

  return newId;

}

  

export async function renameProfile(id, newName) {

  const { profiles } = await getAllProfiles();

  profiles[id].name = newName;

  await setStorage({ profiles });

}

  

// ── Task helpers ─────────────────────────────────────────────────────────────

  

export function generateId() {

  return 'id-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9);

}

  

export async function getTasks() {

  const { profile } = await getActiveProfile();

  return profile.tasks || [];

}

  

export async function saveTasks(tasks) {

  await saveActiveProfile({ tasks });

}

  

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

  

export async function addSubtask(taskId, subtaskTitle) {

  const tasks = await getTasks();

  const task = tasks.find(t => t.id === taskId);

  if (!task) return;

  task.subtasks.push({ id: generateId(), title: subtaskTitle, completed: false, createdAt: Date.now() });

  await saveTasks(tasks);

}

  

export async function toggleSubtask(taskId, subtaskId) {

  const tasks = await getTasks();

  const task = tasks.find(t => t.id === taskId);

  if (!task) return;

  const sub = task.subtasks.find(s => s.id === subtaskId);

  if (sub) sub.completed = !sub.completed;

  await saveTasks(tasks);

}

  

// ── Goals helpers ─────────────────────────────────────────────────────────────

  

export async function getGoals() {

  const { profile } = await getActiveProfile();

  return profile.goals || { daily: [], weekly: [], monthly: [], quarterly: [] };

}

  

export async function saveGoals(goals) {

  await saveActiveProfile({ goals });

}

  

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

  

// ── Session / progress helpers ────────────────────────────────────────────────

  

export async function logSession(domain, minutes) {

  const { profile } = await getActiveProfile();

  const sessions = profile.sessions || [];

  const today = new Date().toISOString().split('T')[0];

  sessions.push({ date: today, domain, minutes, timestamp: Date.now() });

  // Update streak

  const streaks = profile.streaks || { current: 0, longest: 0, lastStudyDate: null };

  if (streaks.lastStudyDate !== today) {

    const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];

    if (streaks.lastStudyDate === yesterday) {

      streaks.current += 1;

    } else {

      streaks.current = 1;

    }

    streaks.longest = Math.max(streaks.longest, streaks.current);

    streaks.lastStudyDate = today;

  }

  await saveActiveProfile({ sessions, streaks });

}

  

export async function getSessionsForDate(date) {

  const { profile } = await getActiveProfile();

  return (profile.sessions || []).filter(s => s.date === date);

}

  

export async function getSessionsForRange(startDate, endDate) {

  const { profile } = await getActiveProfile();

  return (profile.sessions || []).filter(s => s.date >= startDate && s.date <= endDate);

}

  

// ── Export / Import ───────────────────────────────────────────────────────────

  

export async function exportAllProfiles() {

  const { profiles, activeProfile } = await getAllProfiles();

  const exportData = {

    version: '1.0',

    exportedAt: new Date().toISOString(),

    activeProfile,

    profiles

  };

  return JSON.stringify(exportData, null, 2);

}

  

export async function exportCurrentProfile() {

  const { profile, activeProfile, profiles } = await getActiveProfile();

  const exportData = {

    version: '1.0',

    exportedAt: new Date().toISOString(),

    singleProfile: true,

    profileKey: activeProfile,

    profile: { ...profile, name: profiles[activeProfile]?.name, color: profiles[activeProfile]?.color, emoji: profiles[activeProfile]?.emoji }

  };

  return JSON.stringify(exportData, null, 2);

}

  

export async function importData(jsonString, mode = 'merge') {

  const importData = JSON.parse(jsonString);

  const { profiles: currentProfiles } = await getAllProfiles();

  

  if (importData.singleProfile) {

    // Single profile import

    const p = importData.profile;

    if (mode === 'overwrite') {

      const { activeProfile } = await getAllProfiles();

      currentProfiles[activeProfile] = p;

    } else {

      // Import as new profile

      const newId = 'imported-' + Date.now();

      currentProfiles[newId] = p;

      currentProfiles[newId].name = (p.name || 'Imported') + ' (Imported)';

    }

  } else {

    // All profiles import

    if (mode === 'overwrite') {

      await setStorage({ profiles: importData.profiles, activeProfile: importData.activeProfile });

      return;

    } else {

      // Merge: add imported profiles as new entries

      for (const [key, val] of Object.entries(importData.profiles)) {

        const newId = 'imported-' + key + '-' + Date.now();

        currentProfiles[newId] = { ...val, name: (val.name || key) + ' (Imported)' };

      }

    }

  }

  

  await setStorage({ profiles: currentProfiles });

}

  

// ── Theme ─────────────────────────────────────────────────────────────────────

  

export async function getTheme() {

  const data = await getStorage('globalTheme');

  return data.globalTheme || 'dark';

}

  

export async function setTheme(theme) {

  await setStorage({ globalTheme: theme });

}
```


# popup.js 

```

// storage.js — Core data layer for DevPrep Tracker

  

export const DEFAULT_SETTINGS = {

  dailyTargetHours: 6,

  notificationsEnabled: true,

  pomodoroLength: 25,

  shortBreak: 5,

  longBreak: 15,

  theme: 'dark'

};

  

export const DEFAULT_PROFILE = () => ({

  tasks: [],

  goals: { daily: [], weekly: [], monthly: [], quarterly: [] },

  sessions: [],

  streaks: { current: 0, longest: 0, lastStudyDate: null },

  settings: { ...DEFAULT_SETTINGS },

  createdAt: Date.now()

});

  

export const DOMAINS = [

  { key: 'dsa',      label: 'DSA',         icon: '🧩', color: '#f59e0b' },

  { key: 'java',     label: 'Core Java',   icon: '☕', color: '#ef4444' },

  { key: 'spring',   label: 'Spring Boot', icon: '🌱', color: '#10b981' },

  { key: 'devops',   label: 'DevOps',      icon: '⚙️', color: '#3b82f6' },

  { key: 'articles', label: 'Articles',    icon: '📰', color: '#8b5cf6' }

];

  

export const PROFILE_COLORS = [

  '#10b981','#3b82f6','#f59e0b','#ef4444','#8b5cf6','#ec4899','#06b6d4','#84cc16'

];

  

export const PROFILE_EMOJIS = ['☕','🧩','🌱','⚙️','🎯','📚','💻','🚀','🔥','💡'];

  

// ── Storage helpers ──────────────────────────────────────────────────────────

  

export async function getStorage(keys) {

  return browser.storage.local.get(keys);

}

  

export async function setStorage(data) {

  return browser.storage.local.set(data);

}

  

// ── Profile helpers ──────────────────────────────────────────────────────────

  

export async function getAllProfiles() {

  const data = await getStorage(['profiles', 'activeProfile']);

  let profiles = data.profiles || {};

  let activeProfile = data.activeProfile;

  

  // Bootstrap first run

  if (Object.keys(profiles).length === 0) {

    const id = 'java-sde2-prep';

    profiles[id] = { ...DEFAULT_PROFILE(), name: 'Java SDE-2 Prep', color: '#10b981', emoji: '☕' };

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

  let newActive = activeProfile;

  if (activeProfile === id) newActive = Object.keys(profiles)[0];

  await setStorage({ profiles, activeProfile: newActive });

  return newActive;

}

  

export async function switchProfile(id) {

  await setStorage({ activeProfile: id });

}

  

export async function duplicateProfile(id) {

  const { profiles } = await getAllProfiles();

  const source = profiles[id];

  const newId = 'profile-' + Date.now();

  profiles[newId] = JSON.parse(JSON.stringify(source));

  profiles[newId].name = source.name + ' (Copy)';

  profiles[newId].createdAt = Date.now();

  await setStorage({ profiles });

  return newId;

}

  

export async function renameProfile(id, newName) {

  const { profiles } = await getAllProfiles();

  profiles[id].name = newName;

  await setStorage({ profiles });

}

  

// ── Task helpers ─────────────────────────────────────────────────────────────

  

export function generateId() {

  return 'id-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9);

}

  

export async function getTasks() {

  const { profile } = await getActiveProfile();

  return profile.tasks || [];

}

  

export async function saveTasks(tasks) {

  await saveActiveProfile({ tasks });

}

  

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

  

export async function addSubtask(taskId, subtaskTitle) {

  const tasks = await getTasks();

  const task = tasks.find(t => t.id === taskId);

  if (!task) return;

  task.subtasks.push({ id: generateId(), title: subtaskTitle, completed: false, createdAt: Date.now() });

  await saveTasks(tasks);

}

  

export async function toggleSubtask(taskId, subtaskId) {

  const tasks = await getTasks();

  const task = tasks.find(t => t.id === taskId);

  if (!task) return;

  const sub = task.subtasks.find(s => s.id === subtaskId);

  if (sub) sub.completed = !sub.completed;

  await saveTasks(tasks);

}

  

// ── Goals helpers ─────────────────────────────────────────────────────────────

  

export async function getGoals() {

  const { profile } = await getActiveProfile();

  return profile.goals || { daily: [], weekly: [], monthly: [], quarterly: [] };

}

  

export async function saveGoals(goals) {

  await saveActiveProfile({ goals });

}

  

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

  

// ── Session / progress helpers ────────────────────────────────────────────────

  

export async function logSession(domain, minutes) {

  const { profile } = await getActiveProfile();

  const sessions = profile.sessions || [];

  const today = new Date().toISOString().split('T')[0];

  sessions.push({ date: today, domain, minutes, timestamp: Date.now() });

  // Update streak

  const streaks = profile.streaks || { current: 0, longest: 0, lastStudyDate: null };

  if (streaks.lastStudyDate !== today) {

    const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];

    if (streaks.lastStudyDate === yesterday) {

      streaks.current += 1;

    } else {

      streaks.current = 1;

    }

    streaks.longest = Math.max(streaks.longest, streaks.current);

    streaks.lastStudyDate = today;

  }

  await saveActiveProfile({ sessions, streaks });

}

  

export async function getSessionsForDate(date) {

  const { profile } = await getActiveProfile();

  return (profile.sessions || []).filter(s => s.date === date);

}

  

export async function getSessionsForRange(startDate, endDate) {

  const { profile } = await getActiveProfile();

  return (profile.sessions || []).filter(s => s.date >= startDate && s.date <= endDate);

}

  

// ── Export / Import ───────────────────────────────────────────────────────────

  

export async function exportAllProfiles() {

  const { profiles, activeProfile } = await getAllProfiles();

  const exportData = {

    version: '1.0',

    exportedAt: new Date().toISOString(),

    activeProfile,

    profiles

  };

  return JSON.stringify(exportData, null, 2);

}

  

export async function exportCurrentProfile() {

  const { profile, activeProfile, profiles } = await getActiveProfile();

  const exportData = {

    version: '1.0',

    exportedAt: new Date().toISOString(),

    singleProfile: true,

    profileKey: activeProfile,

    profile: { ...profile, name: profiles[activeProfile]?.name, color: profiles[activeProfile]?.color, emoji: profiles[activeProfile]?.emoji }

  };

  return JSON.stringify(exportData, null, 2);

}

  

export async function importData(jsonString, mode = 'merge') {

  const importData = JSON.parse(jsonString);

  const { profiles: currentProfiles } = await getAllProfiles();

  

  if (importData.singleProfile) {

    // Single profile import

    const p = importData.profile;

    if (mode === 'overwrite') {

      const { activeProfile } = await getAllProfiles();

      currentProfiles[activeProfile] = p;

    } else {

      // Import as new profile

      const newId = 'imported-' + Date.now();

      currentProfiles[newId] = p;

      currentProfiles[newId].name = (p.name || 'Imported') + ' (Imported)';

    }

  } else {

    // All profiles import

    if (mode === 'overwrite') {

      await setStorage({ profiles: importData.profiles, activeProfile: importData.activeProfile });

      return;

    } else {

      // Merge: add imported profiles as new entries

      for (const [key, val] of Object.entries(importData.profiles)) {

        const newId = 'imported-' + key + '-' + Date.now();

        currentProfiles[newId] = { ...val, name: (val.name || key) + ' (Imported)' };

      }

    }

  }

  

  await setStorage({ profiles: currentProfiles });

}

  

// ── Theme ─────────────────────────────────────────────────────────────────────

  

export async function getTheme() {

  const data = await getStorage('globalTheme');

  return data.globalTheme || 'dark';

}

  

export async function setTheme(theme) {

  await setStorage({ globalTheme: theme });

}
```


# popup.html

```
<!DOCTYPE html>

<html lang="en">

<head>

  <meta charset="UTF-8">

  <meta name="viewport" content="width=device-width, initial-scale=1.0">

  <title>DevPrep Tracker</title>

  <link rel="stylesheet" href="popup.css">

  <link rel="preconnect" href="https://fonts.googleapis.com">

  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&family=Outfit:wght@300;400;500;600;700&display=swap" rel="stylesheet">

</head>

<body class="theme-dark" id="app-body">

  

  <!-- ══ HEADER ══════════════════════════════════════════════════════════════ -->

  <header class="app-header">

    <div class="header-left">

      <div class="logo-mark">DP</div>

      <div class="profile-switcher" id="profileSwitcher">

        <div class="active-profile" id="activeProfileBtn">

          <span class="profile-emoji" id="headerEmoji">☕</span>

          <span class="profile-name" id="headerProfileName">Loading...</span>

          <span class="chevron">▾</span>

        </div>

        <div class="profile-dropdown hidden" id="profileDropdown">

          <div class="profile-list" id="profileList"></div>

          <div class="profile-actions-row">

            <button class="btn-new-profile" id="btnNewProfile">+ New Profile</button>

            <button class="btn-manage-profiles" id="btnManageProfiles">⚙ Manage</button>

          </div>

        </div>

      </div>

    </div>

    <div class="header-right">

      <div class="clock-block">

        <div class="live-time" id="liveClock">00:00:00</div>

        <div class="live-date" id="liveDate">Mon, 01 Jan</div>

      </div>

      <button class="theme-toggle" id="themeToggle" title="Toggle theme">🌙</button>

    </div>

  </header>

  

  <!-- ══ DAILY STATS BAR ══════════════════════════════════════════════════════ -->

  <div class="stats-bar">

    <div class="stat-chip">

      <span class="stat-icon">🔥</span>

      <span class="stat-val" id="streakCount">0</span>

      <span class="stat-lbl">streak</span>

    </div>

    <div class="stat-chip">

      <span class="stat-icon">⏱</span>

      <span class="stat-val" id="todayPlanned">0h</span>

      <span class="stat-lbl">planned</span>

    </div>

    <div class="stat-chip">

      <span class="stat-icon">✅</span>

      <span class="stat-val" id="todayDone">0</span>

      <span class="stat-lbl">done</span>

    </div>

    <div class="stat-chip">

      <span class="stat-icon">📋</span>

      <span class="stat-val" id="todayTotal">0</span>

      <span class="stat-lbl">total</span>

    </div>

    <div class="pomodoro-chip" id="pomodoroChip">

      <span id="pomoClock">25:00</span>

      <button class="pomo-btn" id="pomoStart">▶</button>

    </div>

  </div>

  

  <!-- ══ NAV TABS ══════════════════════════════════════════════════════════════ -->

  <nav class="tab-nav">

    <button class="tab-btn active" data-tab="today">

      <span class="tab-icon">📅</span><span>Today</span>

    </button>

    <button class="tab-btn" data-tab="goals">

      <span class="tab-icon">🎯</span><span>Goals</span>

    </button>

    <button class="tab-btn" data-tab="domains">

      <span class="tab-icon">📚</span><span>Domains</span>

    </button>

    <button class="tab-btn" data-tab="progress">

      <span class="tab-icon">📊</span><span>Progress</span>

    </button>

    <button class="tab-btn" data-tab="settings">

      <span class="tab-icon">⚙️</span><span>Settings</span>

    </button>

  </nav>

  

  <!-- ══ TAB CONTENT ══════════════════════════════════════════════════════════ -->

  <main class="tab-content">

  

    <!-- TODAY TAB -->

    <div class="tab-pane active" id="tab-today">

      <div class="section-header">

        <h2>Today's Plan</h2>

        <button class="btn-primary" id="btnAddTask">+ Add Task</button>

      </div>

  

      <!-- Domain filter pills -->

      <div class="domain-pills" id="domainFilter">

        <button class="pill active" data-domain="all">All</button>

        <button class="pill" data-domain="dsa">🧩 DSA</button>

        <button class="pill" data-domain="java">☕ Java</button>

        <button class="pill" data-domain="spring">🌱 Spring</button>

        <button class="pill" data-domain="devops">⚙️ DevOps</button>

        <button class="pill" data-domain="articles">📰 Articles</button>

      </div>

  

      <!-- Time summary bar -->

      <div class="time-summary" id="timeSummary">

        <div class="time-bar-wrap">

          <div class="time-bar-fill" id="timeBarFill"></div>

        </div>

        <div class="time-labels">

          <span id="timeUsed">0m done</span>

          <span id="timePlanned">0m planned</span>

        </div>

      </div>

  

      <!-- Task list -->

      <div class="task-list" id="taskList">

        <div class="empty-state" id="emptyState">

          <div class="empty-icon">🎯</div>

          <p>No tasks yet. Add your first task!</p>

        </div>

      </div>

    </div>

  

    <!-- GOALS TAB -->

    <div class="tab-pane" id="tab-goals">

      <div class="goals-tabs">

        <button class="goal-tab active" data-goal="daily">Daily</button>

        <button class="goal-tab" data-goal="weekly">Weekly</button>

        <button class="goal-tab" data-goal="monthly">Monthly</button>

        <button class="goal-tab" data-goal="quarterly">Quarterly</button>

      </div>

      <div class="section-header">

        <h2 id="goalTypeTitle">Daily Goals</h2>

        <button class="btn-primary" id="btnAddGoal">+ Goal</button>

      </div>

      <div class="goals-list" id="goalsList"></div>

    </div>

  

    <!-- DOMAINS TAB -->

    <div class="tab-pane" id="tab-domains">

      <h2 class="tab-title">Study Domains</h2>

      <div class="domains-grid" id="domainsGrid"></div>

    </div>

  

    <!-- PROGRESS TAB -->

    <div class="tab-pane" id="tab-progress">

      <h2 class="tab-title">Progress</h2>

      <div class="progress-section">

        <div class="streak-card">

          <div class="streak-num" id="bigStreak">0</div>

          <div class="streak-label">Day Streak 🔥</div>

          <div class="streak-best">Best: <span id="bestStreak">0</span> days</div>

        </div>

        <div class="heatmap-wrap">

          <div class="heatmap-title">Activity (Last 12 Weeks)</div>

          <div class="heatmap" id="heatmap"></div>

          <div class="heatmap-legend">

            <span>Less</span>

            <div class="legend-boxes"></div>

            <span>More</span>

          </div>

        </div>

        <div class="domain-stats" id="domainStats"></div>

        <div class="weekly-summary" id="weeklySummary"></div>

      </div>

    </div>

  

    <!-- SETTINGS TAB -->

    <div class="tab-pane" id="tab-settings">

      <h2 class="tab-title">Settings</h2>

      <div class="settings-group">

        <div class="settings-label">Daily Study Target</div>

        <div class="settings-row">

          <input type="range" id="dailyTarget" min="1" max="12" value="6" class="slider">

          <span class="slider-val" id="dailyTargetVal">6h</span>

        </div>

      </div>

      <div class="settings-group">

        <div class="settings-label">Pomodoro Length</div>

        <div class="settings-row">

          <input type="range" id="pomodoroLen" min="10" max="60" value="25" class="slider">

          <span class="slider-val" id="pomodoroLenVal">25m</span>

        </div>

      </div>

      <div class="settings-group">

        <div class="settings-label">Short Break</div>

        <div class="settings-row">

          <input type="range" id="shortBreak" min="3" max="15" value="5" class="slider">

          <span class="slider-val" id="shortBreakVal">5m</span>

        </div>

      </div>

      <div class="settings-group">

        <div class="settings-label">Notifications</div>

        <div class="settings-row">

          <label class="toggle-switch">

            <input type="checkbox" id="notifToggle" checked>

            <span class="toggle-slider"></span>

          </label>

          <span class="toggle-label" id="notifLabel">Enabled</span>

        </div>

      </div>

      <div class="settings-group">

        <div class="settings-label">Study Reminders (Daily at)</div>

        <div class="reminder-grid" id="reminderGrid">

          <div class="reminder-row" id="reminderRow0">

            <input type="time" class="time-input reminder-time" data-index="0">

            <select class="domain-select reminder-domain" data-index="0">

              <option value="dsa">🧩 DSA</option>

              <option value="java">☕ Core Java</option>

              <option value="spring">🌱 Spring Boot</option>

              <option value="devops">⚙️ DevOps</option>

              <option value="articles">📰 Articles</option>

            </select>

            <button class="btn-icon btn-del-reminder" data-index="0">✕</button>

          </div>

        </div>

        <button class="btn-secondary" id="btnAddReminder">+ Add Reminder</button>

      </div>

      <div class="settings-divider"></div>

      <div class="settings-label">Data Management</div>

      <div class="data-btn-grid">

        <button class="btn-data" id="btnExportAll">⬇ Export All Profiles</button>

        <button class="btn-data" id="btnExportCurrent">⬇ Export This Profile</button>

        <button class="btn-data btn-import" id="btnImport">⬆ Import Data</button>

        <input type="file" id="importFile" accept=".json" class="hidden">

      </div>

      <div class="last-export" id="lastExport">Last export: never</div>

      <div class="settings-divider"></div>

      <div class="settings-label">Profile Management</div>

      <div class="profile-manage-list" id="profileManageList"></div>

    </div>

  

  </main>

  

  <!-- ══ MODALS ═══════════════════════════════════════════════════════════════ -->

  

  <!-- Add/Edit Task Modal -->

  <div class="modal-overlay hidden" id="taskModal">

    <div class="modal">

      <div class="modal-header">

        <h3 id="taskModalTitle">Add Task</h3>

        <button class="modal-close" id="closeTaskModal">✕</button>

      </div>

      <div class="modal-body">

        <div class="form-group">

          <label>Title</label>

          <input type="text" id="taskTitle" placeholder="e.g. Solve 3 Binary Search problems" class="form-input">

        </div>

        <div class="form-group">

          <label>Description</label>

          <textarea id="taskDesc" placeholder="Notes, links, approach..." class="form-input form-textarea" rows="3"></textarea>

        </div>

        <div class="form-row">

          <div class="form-group half">

            <label>Domain</label>

            <select id="taskDomain" class="form-input">

              <option value="dsa">🧩 DSA</option>

              <option value="java">☕ Core Java</option>

              <option value="spring">🌱 Spring Boot</option>

              <option value="devops">⚙️ DevOps</option>

              <option value="articles">📰 Articles</option>

            </select>

          </div>

          <div class="form-group half">

            <label>Priority</label>

            <select id="taskPriority" class="form-input">

              <option value="P1">🔴 P1 - Critical</option>

              <option value="P2" selected>🟡 P2 - Normal</option>

              <option value="P3">🟢 P3 - Low</option>

            </select>

          </div>

        </div>

        <div class="form-row">

          <div class="form-group half">

            <label>Est. Time (mins)</label>

            <input type="number" id="taskEstTime" value="30" min="5" max="480" class="form-input">

          </div>

          <div class="form-group half">

            <label>Goal Type</label>

            <select id="taskGoalType" class="form-input">

              <option value="daily">Daily</option>

              <option value="weekly">Weekly</option>

              <option value="monthly">Monthly</option>

            </select>

          </div>

        </div>

        <div class="form-row">

          <div class="form-group half">

            <label>Due Date</label>

            <input type="date" id="taskDueDate" class="form-input">

          </div>

          <div class="form-group half">

            <label>Remind At</label>

            <input type="datetime-local" id="taskNotifyAt" class="form-input">

          </div>

        </div>

        <!-- Subtasks -->

        <div class="form-group">

          <label>Subtasks</label>

          <div class="subtask-input-row">

            <input type="text" id="subtaskInput" placeholder="Add subtask..." class="form-input subtask-inp">

            <button class="btn-secondary" id="btnAddSubtask">Add</button>

          </div>

          <div class="subtask-preview" id="subtaskPreview"></div>

        </div>

      </div>

      <div class="modal-footer">

        <button class="btn-secondary" id="cancelTaskModal">Cancel</button>

        <button class="btn-primary" id="saveTaskModal">Save Task</button>

      </div>

    </div>

  </div>

  

  <!-- Add Goal Modal -->

  <div class="modal-overlay hidden" id="goalModal">

    <div class="modal">

      <div class="modal-header">

        <h3>Add Goal</h3>

        <button class="modal-close" id="closeGoalModal">✕</button>

      </div>

      <div class="modal-body">

        <div class="form-group">

          <label>Goal Title</label>

          <input type="text" id="goalTitle" placeholder="e.g. Solve 15 LeetCode problems" class="form-input">

        </div>

        <div class="form-row">

          <div class="form-group half">

            <label>Domain</label>

            <select id="goalDomain" class="form-input">

              <option value="all">🌐 All Domains</option>

              <option value="dsa">🧩 DSA</option>

              <option value="java">☕ Core Java</option>

              <option value="spring">🌱 Spring Boot</option>

              <option value="devops">⚙️ DevOps</option>

              <option value="articles">📰 Articles</option>

            </select>

          </div>

          <div class="form-group half">

            <label>Target</label>

            <input type="number" id="goalTarget" value="1" min="1" class="form-input">

          </div>

        </div>

        <div class="form-row">

          <div class="form-group half">

            <label>Unit</label>

            <input type="text" id="goalUnit" placeholder="tasks / problems / hours" class="form-input" value="tasks">

          </div>

          <div class="form-group half">

            <label>Due Date</label>

            <input type="date" id="goalDueDate" class="form-input">

          </div>

        </div>

      </div>

      <div class="modal-footer">

        <button class="btn-secondary" id="cancelGoalModal">Cancel</button>

        <button class="btn-primary" id="saveGoalModal">Save Goal</button>

      </div>

    </div>

  </div>

  

  <!-- New Profile Modal -->

  <div class="modal-overlay hidden" id="profileModal">

    <div class="modal">

      <div class="modal-header">

        <h3 id="profileModalTitle">New Profile</h3>

        <button class="modal-close" id="closeProfileModal">✕</button>

      </div>

      <div class="modal-body">

        <div class="form-group">

          <label>Profile Name</label>

          <input type="text" id="profileName" placeholder="e.g. Java SDE-2 Prep" class="form-input">

        </div>

        <div class="form-group">

          <label>Pick Emoji</label>

          <div class="emoji-picker" id="emojiPicker"></div>

        </div>

        <div class="form-group">

          <label>Pick Color</label>

          <div class="color-picker" id="colorPicker"></div>

        </div>

      </div>

      <div class="modal-footer">

        <button class="btn-secondary" id="cancelProfileModal">Cancel</button>

        <button class="btn-primary" id="saveProfileModal">Create Profile</button>

      </div>

    </div>

  </div>

  

  <!-- Import Modal -->

  <div class="modal-overlay hidden" id="importModal">

    <div class="modal">

      <div class="modal-header">

        <h3>Import Data</h3>

        <button class="modal-close" id="closeImportModal">✕</button>

      </div>

      <div class="modal-body">

        <p class="import-info" id="importInfo">File loaded. Choose import mode:</p>

        <div class="import-options">

          <label class="radio-option">

            <input type="radio" name="importMode" value="merge" checked>

            <div class="radio-content">

              <strong>Merge</strong>

              <span>Add imported profiles as new entries. Safe — keeps existing data.</span>

            </div>

          </label>

          <label class="radio-option">

            <input type="radio" name="importMode" value="overwrite">

            <div class="radio-content">

              <strong>Overwrite</strong>

              <span>Replace current data entirely. Cannot be undone.</span>

            </div>

          </label>

        </div>

      </div>

      <div class="modal-footer">

        <button class="btn-secondary" id="cancelImportModal">Cancel</button>

        <button class="btn-primary" id="confirmImport">Import</button>

      </div>

    </div>

  </div>

  

  <!-- Toast notification -->

  <div class="toast hidden" id="toast"></div>

  

  <script type="module" src="popup.js"></script>

</body>

</html>
```


# popup.css

```
/* ═══════════════════════════════════════════════════════════

   DevPrep Tracker — CSS

   Font: JetBrains Mono (time/code) + Outfit (body)

   Theme: Deep navy dark / Clean off-white light

═══════════════════════════════════════════════════════════ */

  

/* ── CSS Variables ─────────────────────────────────────── */

:root {

  --font-mono: 'JetBrains Mono', monospace;

  --font-body: 'Outfit', sans-serif;

  --radius: 10px;

  --radius-sm: 6px;

  --radius-lg: 14px;

  --transition: 0.18s ease;

}

  

.theme-dark {

  --bg-primary:    #0d1117;

  --bg-secondary:  #161b22;

  --bg-tertiary:   #21262d;

  --bg-card:       #1a1f29;

  --bg-hover:      #2a2f3d;

  --border:        #30363d;

  --border-light:  #21262d;

  --text-primary:  #e6edf3;

  --text-secondary:#8b949e;

  --text-muted:    #484f58;

  --accent:        #00e5a0;

  --accent-dim:    rgba(0,229,160,0.12);

  --accent-glow:   rgba(0,229,160,0.3);

  --danger:        #f85149;

  --warning:       #f0883e;

  --info:          #58a6ff;

  --success:       #3fb950;

  --dsa-color:     #f59e0b;

  --java-color:    #ef4444;

  --spring-color:  #10b981;

  --devops-color:  #3b82f6;

  --articles-color:#8b5cf6;

  --shadow:        0 4px 20px rgba(0,0,0,0.5);

  --shadow-sm:     0 2px 8px rgba(0,0,0,0.3);

  --glass:         rgba(255,255,255,0.04);

}

  

.theme-light {

  --bg-primary:    #f0f4f8;

  --bg-secondary:  #ffffff;

  --bg-tertiary:   #e8edf3;

  --bg-card:       #ffffff;

  --bg-hover:      #f0f4f8;

  --border:        #d0d7de;

  --border-light:  #e8edf3;

  --text-primary:  #1c2128;

  --text-secondary:#57606a;

  --text-muted:    #8c959f;

  --accent:        #0969da;

  --accent-dim:    rgba(9,105,218,0.1);

  --accent-glow:   rgba(9,105,218,0.2);

  --danger:        #cf222e;

  --warning:       #bc4c00;

  --info:          #0969da;

  --success:       #1a7f37;

  --dsa-color:     #d97706;

  --java-color:    #dc2626;

  --spring-color:  #059669;

  --devops-color:  #2563eb;

  --articles-color:#7c3aed;

  --shadow:        0 4px 12px rgba(0,0,0,0.1);

  --shadow-sm:     0 2px 6px rgba(0,0,0,0.06);

  --glass:         rgba(0,0,0,0.02);

}

  

/* ── Reset & Base ──────────────────────────────────────── */

*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  

html { width: 420px; }

  

body {

  width: 420px;

  min-height: 580px;

  max-height: 680px;

  font-family: var(--font-body);

  font-size: 13px;

  background: var(--bg-primary);

  color: var(--text-primary);

  overflow-x: hidden;

  display: flex;

  flex-direction: column;

  transition: background var(--transition), color var(--transition);

}

  

/* ── Header ────────────────────────────────────────────── */

.app-header {

  display: flex;

  align-items: center;

  justify-content: space-between;

  padding: 10px 14px;

  background: var(--bg-secondary);

  border-bottom: 1px solid var(--border);

  gap: 8px;

  flex-shrink: 0;

}

  

.header-left { display: flex; align-items: center; gap: 8px; flex: 1; min-width: 0; }

.header-right { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }

  

.logo-mark {

  width: 28px; height: 28px;

  background: linear-gradient(135deg, var(--accent), var(--info));

  border-radius: 7px;

  display: flex; align-items: center; justify-content: center;

  font-family: var(--font-mono);

  font-weight: 700; font-size: 11px;

  color: #0d1117;

  flex-shrink: 0;

}

  

.profile-switcher { position: relative; min-width: 0; flex: 1; }

  

.active-profile {

  display: flex; align-items: center; gap: 6px;

  padding: 4px 8px;

  background: var(--bg-tertiary);

  border: 1px solid var(--border);

  border-radius: var(--radius-sm);

  cursor: pointer;

  transition: background var(--transition);

  min-width: 0;

}

.active-profile:hover { background: var(--bg-hover); }

  

.profile-emoji { font-size: 14px; flex-shrink: 0; }

.profile-name {

  font-size: 12px; font-weight: 600;

  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;

  color: var(--text-primary);

}

.chevron { font-size: 10px; color: var(--text-muted); flex-shrink: 0; }

  

.profile-dropdown {

  position: absolute; top: calc(100% + 4px); left: 0;

  width: 200px;

  background: var(--bg-card);

  border: 1px solid var(--border);

  border-radius: var(--radius);

  box-shadow: var(--shadow);

  z-index: 1000;

  overflow: hidden;

}

  

.profile-list { max-height: 160px; overflow-y: auto; }

  

.profile-item {

  display: flex; align-items: center; gap: 8px;

  padding: 8px 12px;

  cursor: pointer;

  transition: background var(--transition);

}

.profile-item:hover { background: var(--bg-hover); }

.profile-item.active { background: var(--accent-dim); }

.profile-item .p-dot {

  width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0;

}

.profile-item .p-name { font-size: 12px; font-weight: 500; flex: 1; }

.profile-item .p-check { color: var(--accent); font-size: 11px; }

  

.profile-actions-row {

  display: flex; gap: 0;

  border-top: 1px solid var(--border);

}

.btn-new-profile, .btn-manage-profiles {

  flex: 1; padding: 8px;

  background: none; border: none; cursor: pointer;

  font-size: 11px; font-weight: 600;

  color: var(--accent); font-family: var(--font-body);

  transition: background var(--transition);

}

.btn-new-profile:hover, .btn-manage-profiles:hover { background: var(--bg-hover); }

.btn-manage-profiles { color: var(--text-secondary); border-left: 1px solid var(--border); }

  

/* ── Clock ─────────────────────────────────────────────── */

.clock-block { text-align: right; }

  

.live-time {

  font-family: var(--font-mono);

  font-size: 15px; font-weight: 700;

  color: var(--accent);

  line-height: 1;

  letter-spacing: 1px;

}

  

.live-date {

  font-size: 10px; color: var(--text-muted);

  font-family: var(--font-mono);

  margin-top: 1px;

}

  

.theme-toggle {

  width: 28px; height: 28px;

  border: 1px solid var(--border);

  border-radius: var(--radius-sm);

  background: var(--bg-tertiary);

  cursor: pointer;

  font-size: 13px;

  display: flex; align-items: center; justify-content: center;

  transition: background var(--transition);

}

.theme-toggle:hover { background: var(--bg-hover); }

  

/* ── Stats Bar ─────────────────────────────────────────── */

.stats-bar {

  display: flex; align-items: center; gap: 4px;

  padding: 6px 12px;

  background: var(--bg-secondary);

  border-bottom: 1px solid var(--border);

  flex-shrink: 0;

}

  

.stat-chip {

  display: flex; align-items: center; gap: 3px;

  padding: 3px 6px;

  background: var(--bg-tertiary);

  border-radius: 20px;

  font-size: 11px;

}

.stat-icon { font-size: 11px; }

.stat-val { font-family: var(--font-mono); font-weight: 700; color: var(--accent); }

.stat-lbl { color: var(--text-muted); font-size: 10px; }

  

.pomodoro-chip {

  margin-left: auto;

  display: flex; align-items: center; gap: 6px;

  padding: 4px 8px;

  background: var(--bg-tertiary);

  border: 1px solid var(--border);

  border-radius: 20px;

}

.pomodoro-chip span {

  font-family: var(--font-mono); font-size: 12px; font-weight: 700;

  color: var(--warning);

  min-width: 36px;

}

.pomo-btn {

  width: 20px; height: 20px;

  border: none; border-radius: 50%;

  background: var(--warning);

  color: #fff; font-size: 8px;

  cursor: pointer; display: flex; align-items: center; justify-content: center;

  transition: transform var(--transition);

}

.pomo-btn:hover { transform: scale(1.15); }

  

/* ── Nav Tabs ──────────────────────────────────────────── */

.tab-nav {

  display: flex;

  background: var(--bg-secondary);

  border-bottom: 1px solid var(--border);

  flex-shrink: 0;

}

  

.tab-btn {

  flex: 1;

  display: flex; flex-direction: column; align-items: center; gap: 2px;

  padding: 7px 4px;

  background: none; border: none; cursor: pointer;

  color: var(--text-muted);

  font-family: var(--font-body); font-size: 10px; font-weight: 500;

  border-bottom: 2px solid transparent;

  transition: all var(--transition);

}

.tab-btn:hover { color: var(--text-secondary); background: var(--bg-hover); }

.tab-btn.active { color: var(--accent); border-bottom-color: var(--accent); }

.tab-icon { font-size: 14px; }

  

/* ── Tab Content ───────────────────────────────────────── */

.tab-content {

  flex: 1;

  overflow: hidden;

  position: relative;

}

  

.tab-pane {

  display: none;

  padding: 12px;

  height: 100%;

  overflow-y: auto;

  flex-direction: column;

  gap: 10px;

}

.tab-pane.active { display: flex; }

.tab-pane::-webkit-scrollbar { width: 4px; }

.tab-pane::-webkit-scrollbar-track { background: transparent; }

.tab-pane::-webkit-scrollbar-thumb { background: var(--border); border-radius: 2px; }

  

.tab-title { font-size: 15px; font-weight: 700; margin-bottom: 4px; }

  

/* ── Section Header ────────────────────────────────────── */

.section-header {

  display: flex; align-items: center; justify-content: space-between;

  margin-bottom: 4px;

}

.section-header h2 { font-size: 14px; font-weight: 700; }

  

/* ── Buttons ───────────────────────────────────────────── */

.btn-primary {

  padding: 6px 12px;

  background: var(--accent);

  color: #0d1117;

  border: none; border-radius: var(--radius-sm);

  font-family: var(--font-body); font-size: 12px; font-weight: 700;

  cursor: pointer;

  transition: all var(--transition);

}

.btn-primary:hover { filter: brightness(1.1); transform: translateY(-1px); }

  

.btn-secondary {

  padding: 6px 12px;

  background: var(--bg-tertiary);

  color: var(--text-primary);

  border: 1px solid var(--border);

  border-radius: var(--radius-sm);

  font-family: var(--font-body); font-size: 12px; font-weight: 500;

  cursor: pointer;

  transition: all var(--transition);

}

.btn-secondary:hover { background: var(--bg-hover); }

  

.btn-icon {

  width: 24px; height: 24px;

  background: none; border: none; border-radius: 4px;

  cursor: pointer; color: var(--text-muted); font-size: 11px;

  display: flex; align-items: center; justify-content: center;

  transition: all var(--transition);

}

.btn-icon:hover { background: var(--bg-hover); color: var(--text-primary); }

.btn-icon.danger:hover { background: rgba(248,81,73,0.1); color: var(--danger); }

  

/* ── Domain Pills ──────────────────────────────────────── */

.domain-pills {

  display: flex; gap: 4px; flex-wrap: wrap;

  margin-bottom: 4px;

}

  

.pill {

  padding: 3px 10px;

  border: 1px solid var(--border);

  border-radius: 20px;

  background: none;

  color: var(--text-secondary);

  font-family: var(--font-body); font-size: 11px; font-weight: 500;

  cursor: pointer;

  transition: all var(--transition);

}

.pill:hover { border-color: var(--accent); color: var(--accent); }

.pill.active {

  background: var(--accent-dim);

  border-color: var(--accent);

  color: var(--accent);

}

  

/* ── Time Summary ──────────────────────────────────────── */

.time-summary { margin-bottom: 8px; }

  

.time-bar-wrap {

  height: 4px; background: var(--bg-tertiary);

  border-radius: 2px; overflow: hidden;

  margin-bottom: 4px;

}

.time-bar-fill {

  height: 100%; width: 0%;

  background: linear-gradient(90deg, var(--accent), var(--info));

  border-radius: 2px;

  transition: width 0.5s ease;

}

  

.time-labels {

  display: flex; justify-content: space-between;

  font-size: 11px; color: var(--text-muted);

  font-family: var(--font-mono);

}

  

/* ── Task List ─────────────────────────────────────────── */

.task-list { display: flex; flex-direction: column; gap: 6px; }

  

.empty-state {

  text-align: center;

  padding: 30px 0;

  color: var(--text-muted);

}

.empty-icon { font-size: 32px; margin-bottom: 8px; }

.empty-state p { font-size: 12px; }

  

/* ── Task Card ─────────────────────────────────────────── */

.task-card {

  background: var(--bg-card);

  border: 1px solid var(--border);

  border-radius: var(--radius);

  padding: 10px 12px;

  transition: all var(--transition);

  border-left: 3px solid var(--border);

}

.task-card:hover { border-color: var(--border-light); box-shadow: var(--shadow-sm); }

.task-card.domain-dsa { border-left-color: var(--dsa-color); }

.task-card.domain-java { border-left-color: var(--java-color); }

.task-card.domain-spring { border-left-color: var(--spring-color); }

.task-card.domain-devops { border-left-color: var(--devops-color); }

.task-card.domain-articles { border-left-color: var(--articles-color); }

.task-card.completed { opacity: 0.55; }

  

.task-header {

  display: flex; align-items: flex-start; gap: 8px;

}

  

.task-check {

  width: 16px; height: 16px; flex-shrink: 0;

  border: 2px solid var(--border);

  border-radius: 4px; cursor: pointer;

  display: flex; align-items: center; justify-content: center;

  margin-top: 1px;

  transition: all var(--transition);

  background: none;

}

.task-check:hover { border-color: var(--accent); }

.task-check.checked {

  background: var(--accent); border-color: var(--accent);

  color: #0d1117; font-size: 10px;

}

  

.task-info { flex: 1; min-width: 0; }

  

.task-title-row {

  display: flex; align-items: center; gap: 6px; flex-wrap: wrap;

}

.task-title {

  font-size: 13px; font-weight: 600;

  line-height: 1.3;

  cursor: pointer;

}

.task-title.done { text-decoration: line-through; color: var(--text-muted); }

  

.priority-badge {

  font-size: 9px; font-weight: 700;

  padding: 1px 5px; border-radius: 3px;

  flex-shrink: 0;

}

.priority-P1 { background: rgba(248,81,73,0.15); color: var(--danger); }

.priority-P2 { background: rgba(240,136,62,0.15); color: var(--warning); }

.priority-P3 { background: rgba(63,185,80,0.15); color: var(--success); }

  

.task-meta {

  display: flex; align-items: center; gap: 8px;

  margin-top: 3px; flex-wrap: wrap;

}

.task-meta-item {

  font-size: 10px; color: var(--text-muted);

  display: flex; align-items: center; gap: 2px;

}

  

.task-actions {

  display: flex; gap: 2px; flex-shrink: 0;

  opacity: 0; transition: opacity var(--transition);

}

.task-card:hover .task-actions { opacity: 1; }

  

.task-desc {

  font-size: 11px; color: var(--text-secondary);

  margin-top: 5px; line-height: 1.4;

  padding-top: 5px;

  border-top: 1px solid var(--border-light);

  display: none;

}

.task-desc.show { display: block; }

  

/* Subtask progress */

.subtask-progress {

  margin-top: 6px;

}

.subtask-bar-wrap {

  height: 3px; background: var(--bg-tertiary); border-radius: 2px;

  overflow: hidden; margin-bottom: 3px;

}

.subtask-bar-fill {

  height: 100%; background: var(--accent);

  border-radius: 2px; transition: width 0.3s ease;

}

.subtask-count { font-size: 10px; color: var(--text-muted); }

  

.subtask-list { margin-top: 6px; display: flex; flex-direction: column; gap: 3px; }

.subtask-item {

  display: flex; align-items: center; gap: 6px;

  padding: 3px 0;

}

.subtask-check {

  width: 13px; height: 13px;

  border: 1.5px solid var(--border); border-radius: 3px;

  cursor: pointer; flex-shrink: 0;

  display: flex; align-items: center; justify-content: center;

  background: none; transition: all var(--transition); font-size: 9px;

}

.subtask-check:hover { border-color: var(--accent); }

.subtask-check.checked { background: var(--accent); border-color: var(--accent); color: #0d1117; }

.subtask-title { font-size: 11px; color: var(--text-secondary); }

.subtask-title.done { text-decoration: line-through; color: var(--text-muted); }

  

/* ── Goals ─────────────────────────────────────────────── */

.goals-tabs {

  display: flex; gap: 0;

  background: var(--bg-tertiary);

  border-radius: var(--radius-sm);

  padding: 2px;

  margin-bottom: 8px;

}

.goal-tab {

  flex: 1; padding: 5px 8px;

  background: none; border: none; border-radius: 6px;

  font-family: var(--font-body); font-size: 11px; font-weight: 500;

  color: var(--text-muted); cursor: pointer;

  transition: all var(--transition);

}

.goal-tab.active {

  background: var(--bg-secondary);

  color: var(--accent);

  box-shadow: var(--shadow-sm);

}

  

.goals-list { display: flex; flex-direction: column; gap: 8px; }

  

.goal-card {

  background: var(--bg-card);

  border: 1px solid var(--border);

  border-radius: var(--radius);

  padding: 10px 12px;

}

.goal-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 6px; }

.goal-title { font-size: 13px; font-weight: 600; }

.goal-progress-text {

  font-family: var(--font-mono); font-size: 11px;

  color: var(--accent);

}

.goal-bar-wrap {

  height: 5px; background: var(--bg-tertiary);

  border-radius: 3px; overflow: hidden; margin-bottom: 5px;

}

.goal-bar-fill {

  height: 100%; background: linear-gradient(90deg, var(--accent), var(--info));

  border-radius: 3px; transition: width 0.4s ease;

}

.goal-footer { display: flex; justify-content: space-between; align-items: center; }

.goal-meta { font-size: 10px; color: var(--text-muted); }

.goal-actions { display: flex; gap: 2px; }

  

/* ── Domains Grid ──────────────────────────────────────── */

.domains-grid { display: flex; flex-direction: column; gap: 8px; }

  

.domain-card {

  background: var(--bg-card);

  border: 1px solid var(--border);

  border-radius: var(--radius);

  padding: 12px;

  border-left: 3px solid var(--border);

}

.domain-card.dsa { border-left-color: var(--dsa-color); }

.domain-card.java { border-left-color: var(--java-color); }

.domain-card.spring { border-left-color: var(--spring-color); }

.domain-card.devops { border-left-color: var(--devops-color); }

.domain-card.articles { border-left-color: var(--articles-color); }

  

.domain-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 6px; }

.domain-label { display: flex; align-items: center; gap: 6px; font-size: 13px; font-weight: 700; }

.domain-task-count { font-family: var(--font-mono); font-size: 11px; color: var(--text-muted); }

.domain-bar-wrap { height: 4px; background: var(--bg-tertiary); border-radius: 2px; overflow: hidden; margin-bottom: 4px; }

.domain-bar-fill { height: 100%; border-radius: 2px; transition: width 0.4s ease; }

.domain-stats-row { display: flex; justify-content: space-between; font-size: 10px; color: var(--text-muted); }

  

/* ── Progress ──────────────────────────────────────────── */

.progress-section { display: flex; flex-direction: column; gap: 10px; }

  

.streak-card {

  background: linear-gradient(135deg, var(--bg-card), var(--bg-tertiary));

  border: 1px solid var(--border);

  border-radius: var(--radius-lg);

  padding: 14px;

  text-align: center;

}

.streak-num {

  font-family: var(--font-mono);

  font-size: 36px; font-weight: 700;

  color: var(--accent); line-height: 1;

}

.streak-label { font-size: 13px; font-weight: 600; margin-top: 4px; }

.streak-best { font-size: 11px; color: var(--text-muted); margin-top: 3px; }

  

.heatmap-wrap {

  background: var(--bg-card);

  border: 1px solid var(--border);

  border-radius: var(--radius);

  padding: 10px;

}

.heatmap-title { font-size: 11px; font-weight: 600; color: var(--text-secondary); margin-bottom: 6px; }

.heatmap {

  display: grid;

  grid-template-columns: repeat(12, 1fr);

  gap: 2px;

}

.heatmap-week { display: grid; grid-template-rows: repeat(7, 1fr); gap: 2px; }

.heatmap-day {

  width: 100%; aspect-ratio: 1;

  border-radius: 2px;

  background: var(--bg-tertiary);

  cursor: pointer;

  transition: transform var(--transition);

}

.heatmap-day:hover { transform: scale(1.3); }

.heatmap-day.level-1 { background: rgba(0,229,160,0.2); }

.heatmap-day.level-2 { background: rgba(0,229,160,0.4); }

.heatmap-day.level-3 { background: rgba(0,229,160,0.65); }

.heatmap-day.level-4 { background: rgba(0,229,160,0.9); }

.theme-light .heatmap-day.level-1 { background: rgba(9,105,218,0.15); }

.theme-light .heatmap-day.level-2 { background: rgba(9,105,218,0.35); }

.theme-light .heatmap-day.level-3 { background: rgba(9,105,218,0.6); }

.theme-light .heatmap-day.level-4 { background: rgba(9,105,218,0.85); }

.heatmap-legend {

  display: flex; align-items: center; gap: 4px;

  margin-top: 5px; font-size: 9px; color: var(--text-muted);

}

.legend-boxes { display: flex; gap: 2px; }

.legend-box {

  width: 10px; height: 10px; border-radius: 2px;

}

  

.domain-stats { display: flex; flex-direction: column; gap: 6px; }

.domain-stat-row {

  display: flex; align-items: center; gap: 8px;

  background: var(--bg-card); border: 1px solid var(--border);

  border-radius: var(--radius-sm); padding: 8px 10px;

}

.ds-label { width: 80px; font-size: 11px; font-weight: 600; flex-shrink: 0; }

.ds-bar-wrap { flex: 1; height: 5px; background: var(--bg-tertiary); border-radius: 3px; overflow: hidden; }

.ds-bar-fill { height: 100%; border-radius: 3px; transition: width 0.4s ease; }

.ds-val { font-family: var(--font-mono); font-size: 10px; color: var(--text-muted); min-width: 30px; text-align: right; }

  

.weekly-summary {

  background: var(--bg-card);

  border: 1px solid var(--border);

  border-radius: var(--radius);

  padding: 10px;

}

.ws-title { font-size: 12px; font-weight: 700; margin-bottom: 8px; }

.ws-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; }

.ws-item { text-align: center; padding: 6px; background: var(--bg-tertiary); border-radius: var(--radius-sm); }

.ws-num { font-family: var(--font-mono); font-size: 18px; font-weight: 700; color: var(--accent); }

.ws-lbl { font-size: 10px; color: var(--text-muted); }

  

/* ── Settings ──────────────────────────────────────────── */

.settings-group { margin-bottom: 12px; }

.settings-label { font-size: 11px; font-weight: 700; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 6px; }

.settings-row { display: flex; align-items: center; gap: 8px; }

.settings-divider { height: 1px; background: var(--border); margin: 12px 0; }

  

.slider {

  flex: 1; -webkit-appearance: none;

  height: 4px; background: var(--bg-tertiary);

  border-radius: 2px; outline: none; cursor: pointer;

}

.slider::-webkit-slider-thumb {

  -webkit-appearance: none;

  width: 14px; height: 14px;

  background: var(--accent); border-radius: 50%;

  cursor: pointer;

}

.slider-val {

  font-family: var(--font-mono); font-size: 12px; font-weight: 700;

  color: var(--accent); min-width: 28px;

}

  

.toggle-switch { display: flex; cursor: pointer; }

.toggle-switch input { display: none; }

.toggle-slider {

  width: 36px; height: 20px;

  background: var(--bg-tertiary); border: 1px solid var(--border);

  border-radius: 10px; position: relative; transition: background var(--transition);

}

.toggle-slider::before {

  content: '';

  position: absolute; top: 2px; left: 2px;

  width: 14px; height: 14px;

  background: var(--text-muted); border-radius: 50%;

  transition: all var(--transition);

}

.toggle-switch input:checked + .toggle-slider { background: var(--accent); border-color: var(--accent); }

.toggle-switch input:checked + .toggle-slider::before { left: 18px; background: #0d1117; }

.toggle-label { font-size: 12px; color: var(--text-secondary); }

  

.reminder-grid { display: flex; flex-direction: column; gap: 4px; margin-bottom: 6px; }

.reminder-row { display: flex; gap: 6px; align-items: center; }

  

.time-input, .domain-select {

  padding: 5px 8px;

  background: var(--bg-tertiary);

  border: 1px solid var(--border);

  border-radius: var(--radius-sm);

  color: var(--text-primary);

  font-family: var(--font-mono); font-size: 12px;

  outline: none;

}

.time-input:focus, .domain-select:focus { border-color: var(--accent); }

.domain-select { flex: 1; }

  

.data-btn-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; margin-bottom: 8px; }

.btn-data {

  padding: 8px 10px;

  background: var(--bg-tertiary);

  border: 1px solid var(--border);

  border-radius: var(--radius-sm);

  color: var(--text-primary);

  font-family: var(--font-body); font-size: 11px; font-weight: 600;

  cursor: pointer; transition: all var(--transition); text-align: center;

}

.btn-data:hover { background: var(--bg-hover); border-color: var(--accent); color: var(--accent); }

.btn-data.btn-import:hover { border-color: var(--info); color: var(--info); }

.last-export { font-size: 10px; color: var(--text-muted); font-family: var(--font-mono); }

  

.profile-manage-list { display: flex; flex-direction: column; gap: 6px; }

.profile-manage-item {

  display: flex; align-items: center; gap: 8px;

  padding: 8px 10px;

  background: var(--bg-card);

  border: 1px solid var(--border);

  border-radius: var(--radius-sm);

}

.pmi-emoji { font-size: 16px; }

.pmi-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }

.pmi-name { flex: 1; font-size: 12px; font-weight: 600; }

.pmi-badge { font-size: 9px; padding: 1px 5px; background: var(--accent-dim); color: var(--accent); border-radius: 3px; }

.pmi-actions { display: flex; gap: 2px; }

  

/* ── Modals ────────────────────────────────────────────── */

.modal-overlay {

  position: fixed; inset: 0;

  background: rgba(0,0,0,0.7);

  display: flex; align-items: flex-end;

  z-index: 2000;

  backdrop-filter: blur(2px);

}

.modal-overlay.hidden { display: none; }

  

.modal {

  width: 100%;

  background: var(--bg-secondary);

  border-radius: var(--radius-lg) var(--radius-lg) 0 0;

  border-top: 1px solid var(--border);

  max-height: 85vh;

  overflow-y: auto;

  animation: slideUp 0.2s ease;

}

@keyframes slideUp {

  from { transform: translateY(30px); opacity: 0; }

  to   { transform: translateY(0);    opacity: 1; }

}

  

.modal-header {

  display: flex; align-items: center; justify-content: space-between;

  padding: 14px 16px 10px;

  border-bottom: 1px solid var(--border);

}

.modal-header h3 { font-size: 15px; font-weight: 700; }

.modal-close {

  width: 26px; height: 26px;

  border: none; background: var(--bg-tertiary);

  border-radius: 50%; cursor: pointer;

  color: var(--text-muted); font-size: 12px;

  display: flex; align-items: center; justify-content: center;

  transition: all var(--transition);

}

.modal-close:hover { background: var(--danger); color: white; }

  

.modal-body { padding: 12px 16px; display: flex; flex-direction: column; gap: 10px; }

.modal-footer {

  padding: 10px 16px 14px;

  display: flex; gap: 8px; justify-content: flex-end;

  border-top: 1px solid var(--border);

}

  

/* Forms */

.form-group { display: flex; flex-direction: column; gap: 4px; }

.form-group label { font-size: 11px; font-weight: 700; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.4px; }

.form-row { display: flex; gap: 8px; }

.form-group.half { flex: 1; }

  

.form-input {

  padding: 7px 10px;

  background: var(--bg-tertiary);

  border: 1px solid var(--border);

  border-radius: var(--radius-sm);

  color: var(--text-primary);

  font-family: var(--font-body); font-size: 12px;

  outline: none; transition: border-color var(--transition);

  width: 100%;

}

.form-input:focus { border-color: var(--accent); }

.form-textarea { resize: vertical; min-height: 60px; }

  

.subtask-input-row { display: flex; gap: 6px; }

.subtask-inp { flex: 1; }

.subtask-preview { display: flex; flex-direction: column; gap: 3px; margin-top: 5px; }

.subtask-preview-item {

  display: flex; align-items: center; justify-content: space-between;

  padding: 4px 8px;

  background: var(--bg-tertiary); border-radius: var(--radius-sm);

  font-size: 11px; color: var(--text-secondary);

}

  

/* Emoji / Color pickers */

.emoji-picker, .color-picker { display: flex; flex-wrap: wrap; gap: 6px; }

.emoji-opt {

  width: 32px; height: 32px;

  border: 2px solid var(--border); border-radius: var(--radius-sm);

  cursor: pointer; font-size: 16px; background: var(--bg-tertiary);

  display: flex; align-items: center; justify-content: center;

  transition: all var(--transition);

}

.emoji-opt:hover, .emoji-opt.selected { border-color: var(--accent); background: var(--accent-dim); }

.color-opt {

  width: 24px; height: 24px;

  border-radius: 50%; cursor: pointer;

  border: 3px solid transparent; transition: all var(--transition);

}

.color-opt:hover, .color-opt.selected { border-color: var(--text-primary); transform: scale(1.15); }

  

/* Import */

.import-info { font-size: 12px; color: var(--text-secondary); }

.import-options { display: flex; flex-direction: column; gap: 8px; }

.radio-option {

  display: flex; align-items: flex-start; gap: 10px;

  padding: 10px; background: var(--bg-tertiary);

  border: 1px solid var(--border); border-radius: var(--radius-sm);

  cursor: pointer; transition: border-color var(--transition);

}

.radio-option:hover { border-color: var(--accent); }

.radio-option input { margin-top: 2px; accent-color: var(--accent); }

.radio-content { display: flex; flex-direction: column; gap: 2px; }

.radio-content strong { font-size: 12px; }

.radio-content span { font-size: 11px; color: var(--text-muted); }

  

/* ── Toast ─────────────────────────────────────────────── */

.toast {

  position: fixed; bottom: 70px; left: 50%; transform: translateX(-50%);

  background: var(--bg-card);

  border: 1px solid var(--border);

  border-radius: var(--radius);

  padding: 8px 16px;

  font-size: 12px; font-weight: 600;

  box-shadow: var(--shadow);

  z-index: 3000;

  animation: toastIn 0.2s ease;

  white-space: nowrap;

}

.toast.hidden { display: none; }

.toast.success { border-color: var(--success); color: var(--success); }

.toast.error { border-color: var(--danger); color: var(--danger); }

.toast.info { border-color: var(--info); color: var(--info); }

@keyframes toastIn {

  from { opacity: 0; transform: translate(-50%, 10px); }

  to   { opacity: 1; transform: translate(-50%, 0); }

}

  

/* ── Misc ──────────────────────────────────────────────── */

.hidden { display: none !important; }

select option { background: var(--bg-secondary); color: var(--text-primary); }
```


# background.js


```
// DevPrep Tracker — Background Service Worker

// Handles alarms, notifications, and background tasks

  

browser.alarms.onAlarm.addListener(async (alarm) => {

  const name = alarm.name;

  

  if (name.startsWith('task-reminder-')) {

    const taskId = name.replace('task-reminder-', '');

    const data = await browser.storage.local.get('profiles');

    const profiles = data.profiles || {};

    const activeKey = (await browser.storage.local.get('activeProfile')).activeProfile;

    const profile = profiles[activeKey];

    if (!profile) return;

  

    const task = (profile.tasks || []).find(t => t.id === taskId);

    if (task && !task.completed) {

      browser.notifications.create(`notif-${taskId}`, {

        type: 'basic',

        iconUrl: browser.runtime.getURL('icons/icon96.png'),

        title: '⏰ DevPrep Reminder',

        message: `Time to work on: ${task.title}`,

        priority: 2

      });

    }

  }

  

  if (name.startsWith('study-session-')) {

    const domain = name.replace('study-session-', '');

    const labels = {

      dsa: 'DSA & LeetCode',

      java: 'Core Java',

      spring: 'Spring Boot',

      devops: 'DevOps',

      articles: 'Articles & Latest'

    };

    browser.notifications.create(`session-${domain}-${Date.now()}`, {

      type: 'basic',

      iconUrl: browser.runtime.getURL('icons/icon96.png'),

      title: '📚 Study Session',

      message: `Time to study ${labels[domain] || domain}! Open DevPrep Tracker.`,

      priority: 2

    });

  }

  

  if (name === 'daily-reset') {

    // Re-register daily reset for next day

    browser.alarms.create('daily-reset', {

      delayInMinutes: 1440

    });

  }

  

  if (name === 'pomodoro-end') {

    browser.notifications.create('pomodoro-done', {

      type: 'basic',

      iconUrl: browser.runtime.getURL('icons/icon96.png'),

      title: '🍅 Pomodoro Complete!',

      message: 'Great work! Take a short break before the next session.',

      priority: 2

    });

  }

  

  if (name === 'pomodoro-break-end') {

    browser.notifications.create('pomodoro-break-done', {

      type: 'basic',

      iconUrl: browser.runtime.getURL('icons/icon96.png'),

      title: '⚡ Break Over!',

      message: 'Break time is up. Ready for the next Pomodoro?',

      priority: 2

    });

  }

});

  

// Handle notification clicks

browser.notifications.onClicked.addListener((notifId) => {

  browser.action.openPopup();

});

  

// Listen for messages from popup

browser.runtime.onMessage.addListener(async (message) => {

  if (message.type === 'SET_ALARM') {

    const { name, delayInMinutes, periodInMinutes } = message;

    const alarmInfo = { delayInMinutes };

    if (periodInMinutes) alarmInfo.periodInMinutes = periodInMinutes;

    await browser.alarms.create(name, alarmInfo);

    return { success: true };

  }

  

  if (message.type === 'CLEAR_ALARM') {

    await browser.alarms.clear(message.name);

    return { success: true };

  }

  

  if (message.type === 'CLEAR_ALL_ALARMS') {

    await browser.alarms.clearAll();

    return { success: true };

  }

  

  if (message.type === 'GET_ALARMS') {

    const alarms = await browser.alarms.getAll();

    return { alarms };

  }

  

  if (message.type === 'START_POMODORO') {

    await browser.alarms.clear('pomodoro-end');

    await browser.alarms.clear('pomodoro-break-end');

    browser.alarms.create('pomodoro-end', { delayInMinutes: message.minutes || 25 });

    return { success: true };

  }

  

  if (message.type === 'START_BREAK') {

    await browser.alarms.clear('pomodoro-break-end');

    browser.alarms.create('pomodoro-break-end', { delayInMinutes: message.minutes || 5 });

    return { success: true };

  }

});

  

console.log('DevPrep Tracker background worker started.');
```