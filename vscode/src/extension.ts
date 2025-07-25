import * as vscode from 'vscode';
import * as childProcess from 'child_process';

export function activate(context: vscode.ExtensionContext) {
    let disposable = vscode.commands.registerCommand('elixirTransform.transformSelection', async () => {
        const path = require('path');
        const editor = vscode.window.activeTextEditor;
        if (!editor) {
            vscode.window.showErrorMessage('No active editor found!');
            return;
        }

        const selection = editor.selection;
        const selectedText = editor.document.getText(selection);
        if (!selectedText) {
            vscode.window.showErrorMessage('No text selected!');
            return;
        }

        const binaryPath = path.resolve(__dirname, '../../extra');
        let commands: string[] = [];
        try {
            const result = childProcess.spawnSync(binaryPath, ['list_transforms'], { encoding: 'utf8' });
            if (result.error) {throw result.error;}
            commands = result.stdout.trim().split(/,\s*/).filter(Boolean);
        } catch (error) {
            vscode.window.showErrorMessage(`Failed to load transform commands: ${(error as Error).message}`);
        }

        const transformFunction = await vscode.window.showQuickPick(commands, {
            title: 'Select the Elixir transform function',
            placeHolder: 'Choose a command to apply',
        });

        if (!transformFunction) {
            vscode.window.showErrorMessage('No command selected!');
            return;
        }

        const escapeElixirString = (input: string): string => {
            let result = input.replace(/\\/g, "\\\\");
            result = result.replace(/"/g, '\\"');
            result = result.replace(/#\{/g, '\\#{');
            return result;
        };

        const escapedInput = escapeElixirString(selectedText);
        const result = childProcess.spawnSync(binaryPath, [transformFunction, escapedInput], { encoding: 'utf8' });
        const rawOutput = result.stdout;

        if (result.error) {
            vscode.window.showErrorMessage(
                `Error executing transform: ${(result.error as Error).message}`
            );

            return;
        }

        editor.edit(editBuilder => {
            editBuilder.replace(selection, rawOutput.trim());
        }).then(success => {
            if (success) {
                vscode.commands.executeCommand('editor.action.reindentlines');
            }
        });
    });

    context.subscriptions.push(disposable);
}

export function deactivate() {}
