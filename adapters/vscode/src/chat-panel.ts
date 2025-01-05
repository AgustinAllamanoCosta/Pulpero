import * as vscode from 'vscode';

class ChatViewProvider implements vscode.WebviewViewProvider {
    public static readonly viewType = 'pulpero.chatView';
    private _view?: vscode.WebviewView;

    constructor(
        private readonly _extensionUri: vscode.Uri,
    ) {}

    public resolveWebviewView(
        webviewView: vscode.WebviewView,
        _context: vscode.WebviewViewResolveContext,
        _token: vscode.CancellationToken,
    ) {
        this._view = webviewView;

        webviewView.webview.options = {
            enableScripts: true,
            localResourceRoots: [this._extensionUri]
        };

        webviewView.webview.html = this._getHtmlForWebview(webviewView.webview);

        webviewView.webview.onDidReceiveMessage(async data => {
            switch (data.type) {
                case 'message':
                    // Handle user message
                    if (data.value) {
                        // Here you would process the message with your service
                        this.addMessage('user', data.value);
                        // Example response:
                        setTimeout(() => {
                            this.addMessage('assistant', `Received: ${data.value}`);
                        }, 1000);
                    }
                    break;
            }
        });
    }

    public addMessage(role: 'user' | 'assistant', content: string) {
        if (this._view) {
            this._view.webview.postMessage({
                type: 'addMessage',
                role,
                content
            });
        }
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
            </script>
        </body>
        </html>`;
    }
}

export function activateChatView(context: vscode.ExtensionContext) {
    const chatViewProvider = new ChatViewProvider(context.extensionUri);

    context.subscriptions.push(
        vscode.window.registerWebviewViewProvider(
            ChatViewProvider.viewType,
            chatViewProvider
        )
    );

    return chatViewProvider;
}
