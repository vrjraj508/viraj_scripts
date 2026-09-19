// Create menu
chrome.runtime.onInstalled.addListener(() => {

    chrome.contextMenus.create({
        id: "root_menu",
        title: "Select Status",
        contexts: ["all"]
    });

    chrome.contextMenus.create({
        id: "create_ticket",
        parentId: "root_menu",
        title: "Create Ticket",
        contexts: ["all"]
    });

    chrome.contextMenus.create({
        id: "create_collab",
        parentId: "root_menu",
        title: "Create Collab",
        contexts: ["all"]
    });

    chrome.contextMenus.create({
        id: "action_taken",
        parentId: "root_menu",
        title: "Action Taken",
        contexts: ["all"]
    });
});


// Date
function getFormattedDate() {
    const now = new Date();

    const date = now.toLocaleDateString('en-GB', {
        day: 'numeric',
        month: 'long',
        year: 'numeric'
    });

    const time = now.toLocaleTimeString('en-GB', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: true
    });

    return `[${date} ${time}]`;
}


// Text generator
function generateText(type) {
    const action = "DV Failed";
    const reason = "Asking for docs from partner";

    let base = `${getFormattedDate()} Action: ${action} //${reason}`;

    switch (type) {
        case "create_ticket":
            return `${base}
[ticket] Ticket created | Additional Issue:`;

        case "create_collab":
            return `${base}
[ticket] Collab created | Issue:
Onevet Link:`;

        default:
            return base;
    }
}


// Create offscreen doc if not exists
async function ensureOffscreen() {
    const existing = await chrome.offscreen.hasDocument?.();
    if (!existing) {
        await chrome.offscreen.createDocument({
            url: "offscreen.html",
            reasons: ["CLIPBOARD"],
            justification: "Copy text"
        });
    }
}


// Handle click
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
    const text = generateText(info.menuItemId);

    try {
        await ensureOffscreen();

        await chrome.runtime.sendMessage({
            type: "COPY",
            text: text
        });

        console.log("Copied:", text);

    } catch (e) {
        console.error("Copy failed:", e);
    }
});