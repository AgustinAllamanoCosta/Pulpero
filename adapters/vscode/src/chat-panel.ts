import * as vscode from 'vscode';

type ChatRecordMessage = {
    role:'user' | 'assistant';
    content: string;
}

type ChatRecord = {
    messages: Array<ChatRecordMessage>
}

class ChatViewProvider implements vscode.WebviewViewProvider {
    public static readonly viewType = 'pulpero.chatView';
    private _view?: vscode.WebviewView;
    private recordKey: string = "pulperoChatReacord";

    constructor(
        private readonly _extContext: vscode.ExtensionContext,
        private memento: vscode.Memento,
    ) {
    }

    public resolveWebviewView(
        webviewView: vscode.WebviewView,
        _context: vscode.WebviewViewResolveContext,
        _token: vscode.CancellationToken,
    ) {
        this._view = webviewView;

        webviewView.webview.options = {
            enableScripts: true,
            localResourceRoots: [this._extContext.extensionUri]
        };

        webviewView.webview.html = this._getHtmlForWebview(webviewView.webview);

        webviewView.webview.onDidReceiveMessage(async data => {
            switch (data.type) {
                case 'message':
                    if (data.value) {
                        const message: ChatRecordMessage = { role: 'user', content: data.value }; 
                        this.addMessageAndRecord(message);
                        setTimeout(() => {
                            const message: ChatRecordMessage = { role: 'assistant', content: `Received: ${data.value}`}; 
                            this.addMessageAndRecord(message);
                        }, 1000);
                    }
                    break;
                case 'requestHistory':
                    this.loadRecords();
                    break;
            }
        });
    }

    public addMessage({role, content }: ChatRecordMessage) {
        if (this._view) {
            this._view.webview.postMessage({
                type: 'addMessage',
                role,
                content
            });
            return true;
        }
        return false;
    }

    public addMessageAndRecord({role, content }: ChatRecordMessage) {
        const wasPublished: boolean = this.addMessage({role, content});
        if (wasPublished) {
            const recordMessage: ChatRecordMessage = {
                role,
                content
            };
            const record: ChatRecord = this.memento.get<ChatRecord>(this.recordKey, { messages: [] });
            record.messages.push(recordMessage);
            this.memento.update(this.recordKey, record);
        }
    }

    public loadRecords() {
        const records: ChatRecord = this.memento.get<ChatRecord>(this.recordKey, { messages: [] });
        records.messages.forEach((message: ChatRecordMessage) => {
            this.addMessage(message);
        });
    }

    private _getHtmlForWebview(_webview: vscode.Webview) {
        return `<!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    padding: 0;
                    margin: 0;
                    font-family: var(--vscode-font-family);
                }
                .chat-container {
                    display: flex;
                    flex-direction: column;
                    height: 100vh;
                }
                .messages {
                    flex: 1;
                    overflow-y: auto;
                    padding: 10px;
                }
                .message {
                    margin: 8px 0;
                    padding: 8px;
                    border-radius: 4px;
                    max-width: 85%;
                }
                .user-message {
                    margin-left: auto;
                    background: var(--vscode-button-background);
                    color: var(--vscode-button-foreground);
                }
                .assistant-message {
                    margin-right: auto;
                    background: var(--vscode-editor-lineHighlightBackground);
                }
                .input-container {
                    padding: 10px;
                    border-top: 1px solid var(--vscode-panel-border);
                }
                .message-input {
                    width: 100%;
                    padding: 6px;
                    border: 1px solid var(--vscode-input-border);
                    background: var(--vscode-input-background);
                    color: var(--vscode-input-foreground);
                    border-radius: 4px;
                }
            </style>
        </head>
        <body>
            <div class="chat-container">
                <div class="messages" id="messages"></div>
                <div class="input-container">
                </div>
            </div>

            <script>
                const vscode = acquireVsCodeApi();
                const messagesContainer = document.getElementById('messages');

                window.addEventListener('message', event => {
                    const message = event.data;
                    switch (message.type) {
                        case 'addMessage':
                            const messageDiv = document.createElement('div');
                            messageDiv.classList.add('message');
                            messageDiv.classList.add(message.role === 'user' ? 'user-message' : 'assistant-message');
                            messageDiv.textContent = message.content;
                            messagesContainer.appendChild(messageDiv);
                            messageDiv.scrollIntoView({ behavior: 'smooth' });
                            break;
                    }
                });
                document.addEventListener('DOMContentLoaded', () => {
                vscode.postMessage({
                    type: 'requestHistory',
                    });
                });
            </script>
        </body>
        </html>`;
    }
}

export function activateChatView(context: vscode.ExtensionContext) {
    const chatViewProvider = new ChatViewProvider(context, context.workspaceState);

    context.subscriptions.push(
        vscode.window.registerWebviewViewProvider(
            ChatViewProvider.viewType,
            chatViewProvider
        )
    );

    return chatViewProvider;
}
