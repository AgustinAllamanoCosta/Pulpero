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
    private readonly versionsUrl = 'https://raw.githubusercontent.com/AgustinAllamanoCosta/pulpero/main/releases/version.json';
    private readonly coreDir: string;
    private readonly isLocal: boolean;
    private readonly pathToLocalCore: string;

    constructor(context: vscode.ExtensionContext, isLocal: boolean = false, pathToLocalCore: string = "") {
        this.storageUri = context.globalStorageUri;
        this.coreDir = path.join(this.storageUri.fsPath, 'core');
        this.isLocal = isLocal;
        this.pathToLocalCore = pathToLocalCore;
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
        if (this.isLocal) {
            const tmpVersionFile = path.join(this.pathToLocalCore, 'local-version.json');
            const rawData = fs.readFileSync(tmpVersionFile);
            const { versions } = JSON.parse(rawData.toString());
            return versions[versions.length - 1];

        } else {
            const response = await fetch(this.versionsUrl);
            const { versions } = await response.json();
            return versions[versions.length - 1];
        }
    }

    private async extractLocalFile(filePath: string, version: string): Promise<void> {

        fs.mkdirSync(this.coreDir, { recursive: true });
        await tar.x({
            file: filePath,
            cwd: this.coreDir,
            strip: 1
        });

        fs.writeFileSync(
            path.join(this.coreDir, 'version'),
            version
        );
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
                    if (this.isLocal) {
                        progress.report({ message: "Sync is in process..." });
                        const tmpFile = path.join(this.pathToLocalCore, 'core-local.tar.gz');
                        this.extractLocalFile(tmpFile, latestVersion.version);
                        progress.report({ message: "Sync is complete" });

                    } else {
                        progress.report({ message: "Downloading..." });
                        const response = await fetch(latestVersion.url);
                        const tmpFile = path.join(this.storageUri.fsPath, 'core-download.tar.gz');

                        const fileStream = fs.createWriteStream(tmpFile);

                        fs.mkdirSync(path.dirname(tmpFile), { recursive: true });

                        await new Promise((resolve, reject) => {
                            response.body.pipe(fileStream);
                            response.body.on('error', reject);
                            fileStream.on('finish', resolve);
                        });
                        await this.extractLocalFile(tmpFile, latestVersion.version)

                        fs.unlinkSync(tmpFile);
                        progress.report({ message: "Installation complete" });
                    }
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
