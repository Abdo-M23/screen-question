# screen-question

Press a Windows shortcut while a multiple-choice question is visible. The script captures the monitor containing the active window, sends the screenshot to Codex, and shows the selected choice in a native Windows message box. It supports questions with multiple correct choices.

## Setup on Windows 10

1. In PowerShell, run this one-time setup command. It installs or reuses Codex, installs the listener, and starts ChatGPT device sign-in if needed.

   ```powershell
   irm https://raw.githubusercontent.com/Abdo-M23/screen-question/main/setup.ps1 | iex
   ```

   Open the link it prints on your phone or another computer and enter the code there. If needed, enable **Device code login** in ChatGPT under **Settings → Security**. As a fallback, run `codex login` for browser sign-in. Setup uses the official Windows ZIP on a fresh machine and works without `tar.exe`, Git, or administrator rights. You can [read the setup script](setup.ps1) before running it.

2. Start the listener from the same PowerShell window. Use the same command whenever you want to start it again.

   ```powershell
   screen-question
   ```

## Shortcuts

| Shortcut | Action |
| --- | --- |
| **Ctrl+Alt+F9** | Capture the active monitor and get an answer |
| **Ctrl+Alt+F10** | Stop the listener after dismissing any open message box |
| **Ctrl+C** | Stop from the PowerShell window |

Keep the question, all choices, and any required diagram visible. The listener stays active while the PowerShell window is open and handles one request at a time. If F9 is already registered by another app, run `screen-question -CaptureKey F8`.

Everything visible on the captured monitor is included in the screenshot. The script removes its temporary PNG after each request, including timeouts. If PowerShell is forcibly terminated during a request, the PNG may remain in a `screen-question-hotkey-*` folder under `%TEMP%`.

The periodic-capture script is available as [Screen-Question.ps1](Screen-Question.ps1).
