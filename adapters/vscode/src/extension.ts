import * as vscode from 'vscode';
import * as path from 'path';
import { PulperoService } from './service';
import { CoreManager } from './core-manager';

export async function activate(context: vscode.ExtensionContext) {

    const coreManager = new CoreManager(context);

    const corePath = await coreManager.ensureCore();

    const service = new PulperoService({
        luaPath: vscode.workspace.getConfiguration('pulpero').get('luaPath') || 'lua',
        servicePath: path.join(corePath, 'service.lua')
    });

    service.start().catch(console.error);

    let disposable = vscode.commands.registerCommand(
        'pulpero.explainCode',
        async () => {
            const editor = vscode.window.activeTextEditor;
            if (editor) {
                const selection = editor.document.getText(editor.selection);
                try {
                    const explanation = await service.explainFunction(
                        editor.document.languageId,
                        selection
                    );
                    vscode.window.showInformationMessage(explanation);
                } catch (error) {
                    vscode.window.showErrorMessage(
                        `Failed to explain code: ${error instanceof Error ? error.message : String(error)}`
                    );
                }
            }
        }
    );

    context.subscriptions.push(disposable);

    context.subscriptions.push({
        dispose: () => service.stop()
    });

    setInterval(() => {
        coreManager.checkForUpdates();
    }, 24 * 60 * 60 * 1000);
}

export function deactivate() {
}
