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

        const fs = require('fs');
        const toolDir = path.resolve(__dirname, '../../lib/tools');

        let commands: string[] = [];
        try {
            commands = fs
                .readdirSync(toolDir)
                .filter((file: string) => file.endsWith('.ex'))
                .map((file: string) => path.basename(file, '.ex'));
        } catch (error) {
            vscode.window.showErrorMessage(`Failed to load commands: ${(error as Error).message}`);
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
        const binaryPath = path.resolve(__dirname, '../../extra');
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
