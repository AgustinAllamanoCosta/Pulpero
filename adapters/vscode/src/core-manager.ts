import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import fetch from 'node-fetch';
import * as tar from 'tar';

interface VersionInfo {
    version: string;
    url: string;
    checksum: string;
    releaseDate: string;
    minEditorVersion: string;
    breaking: boolean;
}

export class CoreManager {
    private readonly storageUri: vscode.Uri;
    private readonly versionsUrl = 'https://raw.githubusercontent.com/AgustinAllamanoCosta/pulpero/main/releases/versions.json';
    private readonly coreDir: string;

    constructor(context: vscode.ExtensionContext) {
        this.storageUri = context.globalStorageUri;
        this.coreDir = path.join(this.storageUri.fsPath, 'core');
    }

    private async getCurrentVersion(): Promise<string | null> {
        const versionFile = path.join(this.coreDir, 'version');
        try {
            if (fs.existsSync(versionFile)) {
                return fs.readFileSync(versionFile, 'utf8').trim();
            }
        } catch (error) {
            console.error('Error reading current version:', error);
        }
        return null;
    }

    private async getLatestVersionInfo(): Promise<VersionInfo> {
        const response = await fetch(this.versionsUrl);
        const versions: VersionInfo[] = await response.json();
        return versions[0];
    }

    private async downloadAndExtractCore(versionInfo: VersionInfo): Promise<void> {
        const response = await fetch(versionInfo.url);
        const tmpFile = path.join(this.storageUri.fsPath, 'core-download.tar.gz');

        fs.mkdirSync(path.dirname(tmpFile), { recursive: true });

        const fileStream = fs.createWriteStream(tmpFile);
        await new Promise((resolve, reject) => {
            response.body.pipe(fileStream);
            response.body.on('error', reject);
            fileStream.on('finish', resolve);
        });

        await tar.x({
            file: tmpFile,
            cwd: this.coreDir,
            strip: 1
        });

        fs.writeFileSync(
            path.join(this.coreDir, 'version'),
            versionInfo.version
        );

        fs.unlinkSync(tmpFile);
    }

    public async ensureCore(): Promise<string> {
        const currentVersion = await this.getCurrentVersion();
        const latestVersion = await this.getLatestVersionInfo();

        if (!currentVersion || currentVersion !== latestVersion.version) {
            await vscode.window.withProgress(
                {
                    location: vscode.ProgressLocation.Notification,
                    title: "Updating Pulpero Core",
                    cancellable: false
                },
                async (progress) => {
                    progress.report({ message: "Downloading..." });
                    await this.downloadAndExtractCore(latestVersion);
                    progress.report({ message: "Installation complete" });
                }
            );
        }

        return this.coreDir;
    }

    public async checkForUpdates(): Promise<void> {
        const currentVersion = await this.getCurrentVersion();
        const latestVersion = await this.getLatestVersionInfo();

        if (currentVersion !== latestVersion.version) {
            const update = await vscode.window.showInformationMessage(
                `A new version of Pulpero Core is available (${latestVersion.version})`,
                'Update Now',
                'Later'
            );

            if (update === 'Update Now') {
                await this.ensureCore();
            }
        }
    }
}
