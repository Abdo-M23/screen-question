# screen-question

Press a Windows shortcut while a multiple-choice question is visible. The script captures the monitor containing the active window, sends the screenshot to Codex, and shows the selected choice in a native Windows message box. It supports questions with multiple correct choices.

## Setup on Windows 10

1. Install the [standalone Codex CLI for Windows](https://github.com/openai/codex#quickstart). Open a new PowerShell window afterward so it can find `codex.exe`. The script does not need administrator rights.
2. Run `codex login` and sign in with your ChatGPT account. Use `codex login status` to verify the sign-in. The script uses your Codex allowance.
3. Download and run the script. Git is optional.

   ```powershell
   Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/Abdo-M23/screen-question/main/Screen-Question-Hotkey.ps1' -OutFile .\Screen-Question-Hotkey.ps1
   Unblock-File -LiteralPath .\Screen-Question-Hotkey.ps1
   powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\Screen-Question-Hotkey.ps1
   ```

## Shortcuts

| Shortcut | Action |
| --- | --- |
| **Ctrl+Alt+F9** | Capture the active monitor and get an answer |
| **Ctrl+Alt+F10** | Stop the listener after dismissing any open message box |
| **Ctrl+C** | Stop from the PowerShell window |

Keep the question, all choices, and any required diagram visible. The listener stays active while the PowerShell window is open and handles one request at a time. If F9 is already registered by another app, add `-CaptureKey F8` after the script name in the launch command.

Everything visible on the captured monitor is included in the screenshot. The script removes its temporary PNG after each request, including timeouts. If PowerShell is forcibly terminated during a request, the PNG may remain in a `screen-question-hotkey-*` folder under `%TEMP%`.

The periodic-capture script is available as [Screen-Question.ps1](Screen-Question.ps1).
