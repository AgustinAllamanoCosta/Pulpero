export interface ServiceOptions {
    luaPath?: string;
    servicePath?: string;
    maxBuffer?: number;
    timeout?: number;
    corePath?: string;
}

export interface ServiceRequest {
    id: number;
    method: string;
    params: Record<string, unknown>;
}

export interface ServiceResponse {
    requestId: number;
    result?: string;
    error?: string;
}

export interface PendingRequest {
    resolve: (value: unknown) => void;
    reject: (reason?: any) => void;
}

interface LuaPaths {
    LUA_PATH: string;
    LUA_CPATH: string;
}

function getPlatformPaths(coreUri: string): LuaPaths {
    const isWindows = process.platform === 'win32';
    const isMac = process.platform === 'darwin';

    if (isWindows) {
        return {
            LUA_PATH: `C:\\Program Files\\Lua\\?.lua;C:\\Program Files\\Lua\\?\\init.lua;${coreUri}\\?.lua`,
            LUA_CPATH: `C:\\Program Files\\Lua\\?.dll;C:\\Program Files\\Lua\\loadall.dll`
        };
    } else if (isMac) {
        return {
            LUA_PATH: `/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;${coreUri}/?.lua`,
            LUA_CPATH: `/usr/local/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so`
        };
    } else {
        return {
            LUA_PATH: `/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;${coreUri}/?.lua`,
            LUA_CPATH: `/usr/lib/lua/5.1/?.so;/usr/lib/x86_64-linux-gnu/lua/5.1/?.so`
        };
    }
}

import { spawn, ChildProcess } from 'child_process';
import * as path from 'path';
import { EventEmitter } from 'events';

export class PulperoService extends EventEmitter {
    private options: Required<ServiceOptions>;
    private process: ChildProcess | null;
    private requestQueue: Map<number, PendingRequest>;
    private nextRequestId: number;

    constructor(options: ServiceOptions = {}) {
        super();
        this.options = {
            luaPath: options.luaPath || 'lua',
            servicePath: options.servicePath || path.join(__dirname, 'service.lua'),
            maxBuffer: options.maxBuffer || 1024 * 1024 * 10,
            timeout: options.timeout || 30000,
            corePath: options.corePath || __dirname
        };
        this.process = null;
        this.requestQueue = new Map();
        this.nextRequestId = 1;
    }

    public async start(): Promise<void> {
        if (this.process) {
            return;
        }

        const platformPaths = getPlatformPaths(this.options.corePath);
        const env = {
            ...process.env,
            ...platformPaths
        };

        return new Promise<void>((resolve, reject) => {
            try {
                this.process = spawn(this.options.luaPath, [this.options.servicePath], {
                    stdio: ['pipe', 'pipe', 'pipe'],
                    env: env
                });

                if (!this.process.stdout || !this.process.stderr || !this.process.stdin) {
                    throw new Error('Failed to create process streams');
                }

                this.process.stdout.on('data', (data: Buffer) => {
                    try {
                        const message = data.toString().trim();
                        const response = JSON.parse(message) as ServiceResponse;
                        const { requestId, result, error } = response;
                        const pending = this.requestQueue.get(requestId);
                        if (pending) {
                            this.requestQueue.delete(requestId);
                            if (error) {
                                pending.reject(new Error(error));
                            } else {
                                pending.resolve(result);
                            }
                        }
                    } catch (err) {
                        console.error('Error processing response:', err);
                    }
                });

                this.process.stderr.on('data', (data: Buffer) => {
                    console.error(`Lua Service Error: ${data}`);
                });

                this.process.on('error', (err: Error) => {
                    reject(new Error(`Failed to start Lua service: ${err.message}`));
                });

                this.process.on('exit', (code: number | null, signal: string | null) => {
                    if (code !== 0) {
                        console.error(`Service exited with code ${code}`);
                    }
                    this.process = null;
                    this.emit('exit', code, signal);
                });

                setTimeout(() => {
                    if (this.process) {
                        resolve();
                    } else {
                        reject(new Error('Service failed to start'));
                    }
                }, 1000);

            } catch (error) {
                reject(new Error(`Failed to start service: ${error instanceof Error ? error.message : String(error)}`));
            }
        });
    }

    public async stop(): Promise<void> {
        if (!this.process) {
            return;
        }

        this.process.kill();
        this.process = null;

        for (const [id, { reject }] of this.requestQueue) {
            reject(new Error('Service stopped'));
            this.requestQueue.delete(id);
        }
    }

    public async explainFunction(language: string, code: string): Promise<string> {
        return this._sendRequest('explain_function', { language, code }) as Promise<string>;
    }

    public async talkWithModel(message: string): Promise<string> {
        return this._sendRequest('talk_with_model', { message }) as Promise<string>;
    }

    private async _sendRequest(method: string, params: Record<string, unknown>): Promise<unknown> {
        if (!this.process || !this.process.stdin) {
            throw new Error('Service not running');
        }

        const requestId = this.nextRequestId++;
        const request: ServiceRequest = {
            id: requestId,
            method,
            params
        };

        return new Promise((resolve, reject) => {
            const timeout = setTimeout(() => {
                this.requestQueue.delete(requestId);
                reject(new Error('Request timed out'));
            }, this.options.timeout);

            this.requestQueue.set(requestId, {
                resolve: (result: unknown) => {
                    clearTimeout(timeout);
                    resolve(result);
                },
                reject: (error: Error) => {
                    clearTimeout(timeout);
                    reject(error);
                }
            });

            this.process?.stdin?.write(JSON.stringify(request) + '\n');
        });
    }
}
