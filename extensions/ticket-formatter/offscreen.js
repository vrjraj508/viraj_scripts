chrome.runtime.onMessage.addListener((msg) => {
    if (msg.type === "COPY") {
        try {
            const textarea = document.createElement("textarea");
            textarea.value = msg.text;

            // Important for Edge
            textarea.style.position = "fixed";
            textarea.style.opacity = "0";

            document.body.appendChild(textarea);
            textarea.focus();
            textarea.select();

            const success = document.execCommand("copy");

            if (success) {
                console.log("Clipboard success");
            } else {
                console.error("execCommand failed");
            }

            document.body.removeChild(textarea);

        } catch (e) {
            console.error("Clipboard failed:", e);
        }
    }
});