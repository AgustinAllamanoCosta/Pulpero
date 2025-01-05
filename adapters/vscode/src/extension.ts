import * as vscode from 'vscode';
import * as path from 'path';
import { PulperoService } from './service';
import { CoreManager } from './core-manager';
import { activateChatView } from './chat-panel';

export async function activate(context: vscode.ExtensionContext) {
    const isLocal: boolean = vscode.workspace.getConfiguration('pulpero').get('local') || false;
    const localCorePath: string = vscode.workspace.getConfiguration('pulpero').get('corePath') || "";
    const coreManager = new CoreManager(context, isLocal, localCorePath);

    const corePath = await coreManager.ensureCore();

    const service = new PulperoService({
        luaPath: vscode.workspace.getConfiguration('pulpero').get('luaPath') || 'lua',
        servicePath: path.join(corePath, 'service.lua'),
        corePath: corePath
    });

    await service.start().catch(console.error);

    const chatView = activateChatView(context);

    let explainDisposable = vscode.commands.registerCommand(
        'pulpero.explainCode',
        async () => {
            const editor = vscode.window.activeTextEditor;
            if (editor) {
                const selection = editor.document.getText(editor.selection);
                try {
                    chatView.addMessage('user', 'Selected code:\n```' + selection + '```');
                    const explanation = await service.explainFunction(
                        editor.document.languageId,
                        selection
                    );
                    chatView.addMessage('assistant', explanation);
                } catch (error) {
                    vscode.window.showErrorMessage(
                        `Failed to explain code: ${error instanceof Error ? error.message : String(error)}`
                    );
                }
            }
        }
    );

    context.subscriptions.push(explainDisposable, {
        dispose: () => service.stop()
    });

    setInterval(() => {
        coreManager.checkForUpdates();
    }, 24 * 60 * 60 * 1000);
}

export function deactivate() {
}
