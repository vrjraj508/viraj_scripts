// StudyFlow Tracker — Background Service Worker

browser.alarms.onAlarm.addListener(async (alarm) => {
  const name = alarm.name;

  if (name.startsWith('task-reminder-')) {
    const taskId = name.replace('task-reminder-', '');
    const data = await browser.storage.local.get(['profiles', 'activeProfile']);
    const profiles = data.profiles || {};
    const profile  = profiles[data.activeProfile];
    if (!profile) return;
    const task = (profile.tasks || []).find(t => t.id === taskId);
    if (task && !task.completed) {
      browser.notifications.create(`notif-${taskId}`, {
        type: 'basic',
        iconUrl: browser.runtime.getURL('icons/icon96.png'),
        title: '⏰ StudyFlow Reminder',
        message: `Time to work on: ${task.title}`,
        priority: 2
      });
    }
  }

  if (name === 'pomodoro-end') {
    browser.notifications.create('pomodoro-done', {
      type: 'basic',
      iconUrl: browser.runtime.getURL('icons/icon96.png'),
      title: '🍅 Pomodoro Complete!',
      message: 'Great work! Take a short break.',
      priority: 2
    });
  }

  if (name === 'pomodoro-break-end') {
    browser.notifications.create('pomodoro-break-done', {
      type: 'basic',
      iconUrl: browser.runtime.getURL('icons/icon96.png'),
      title: '⚡ Break Over!',
      message: 'Ready for the next session?',
      priority: 2
    });
  }
});

browser.notifications.onClicked.addListener(() => {
  browser.action.openPopup();
});

browser.runtime.onMessage.addListener(async (message) => {
  if (message.type === 'SET_ALARM') {
    const { name, delayInMinutes, periodInMinutes } = message;
    const info = { delayInMinutes };
    if (periodInMinutes) info.periodInMinutes = periodInMinutes;
    await browser.alarms.create(name, info);
    return { success: true };
  }
  if (message.type === 'CLEAR_ALARM')     { await browser.alarms.clear(message.name); return { success: true }; }
  if (message.type === 'CLEAR_ALL_ALARMS'){ await browser.alarms.clearAll();           return { success: true }; }
  if (message.type === 'GET_ALARMS')      { return { alarms: await browser.alarms.getAll() }; }
  if (message.type === 'START_POMODORO') {
    await browser.alarms.clear('pomodoro-end');
    browser.alarms.create('pomodoro-end', { delayInMinutes: message.minutes || 25 });
    return { success: true };
  }
  if (message.type === 'START_BREAK') {
    await browser.alarms.clear('pomodoro-break-end');
    browser.alarms.create('pomodoro-break-end', { delayInMinutes: message.minutes || 5 });
    return { success: true };
  }
});

console.log('StudyFlow background worker started.');