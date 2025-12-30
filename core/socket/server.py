import asyncio
import os
import signal
import tempfile
from pathlib import Path
from typing import Optional, List, Any
from core.socket.data_model import ServerRequest, ServerResponse
from core.util.logger import Logger
from core.socket.methods import Methods

class Server:

    logger: Logger
    enable: bool
    methods: Methods
    clients: List[asyncio.StreamWriter]
    server: asyncio.Server | None
    socket_dir: str
    socket_path: Path
    pid_file: Path

    def __init__(self, logger: Logger, methods: Methods) -> None:
        self.logger = logger
        self.enable = True
        self.methods = methods
        self.clients: List[asyncio.StreamWriter] = []
        self.server: Optional[asyncio.Server] = None
        self.socket_dir = tempfile.gettempdir()
        self.socket_path = Path(self.socket_dir) / "pulpero.sock"
        self.pid_file = Path(self.socket_dir) / "pulpero.pid"

    async def process_request(self, request_dict: dict[str, Any]) -> ServerResponse:
        self.logger.debug("Processing request by service", {"request": request_dict})

        if not request_dict:
            self.logger.error("Request process failed - empty request")
            return ServerResponse(requestId= 0, result=None, error='Empty Request')

        self.logger.debug("Processing request", {"request": request_dict})
        request: ServerRequest = ServerRequest(
                method = request_dict['method'],
                Id = request_dict['Id'],
                params = request_dict['params']
        )
        response = self.methods.adapter(request)

        self.logger.info(f"Request processed {response.requestId} {response.result}")
        return response

    async def handle_client(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        self.logger.debug("New client connected")
        self.clients.append(writer)

        try:
            while True:
                data = await reader.readline()

                if not data:
                    self.logger.debug("Client disconnected")
                    break

                line = data.decode('utf-8').strip()
                if line:
                    try:
                        request_dict = eval(line)
                        response = await self.process_request(request_dict)

                        response_str = str(response) + "\n"
                        writer.write(response_str.encode('utf-8'))
                        await writer.drain()
                    except Exception as e:
                        self.logger.error(f"Error processing request {'error': str(e)}")
                        error_response = {
                            "requestId": 0,
                            "error": f"Error processing request: {str(e)}",
                            "result": None
                        }
                        writer.write((str(error_response) + "\n").encode('utf-8'))
                        await writer.drain()

        except asyncio.CancelledError:
            self.logger.error("Client handler cancelled")
        except Exception as e:
            error_msg = str(e)
            self.logger.error(f"Error reading from client {error_msg}")
        finally:
            try:
                writer.close()
                await writer.wait_closed()
            except Exception:
                pass

            if writer in self.clients:
                self.clients.remove(writer)

    async def setup_socket_server(self) -> bool:
        self.socket_path.parent.mkdir(parents=True, exist_ok=True)

        if self.socket_path.exists():
            self.socket_path.unlink()

        try:
            self.server = await asyncio.start_unix_server(
                self.handle_client,
                path=str(self.socket_path)
            )
            self.logger.info(f"Socket server listening {'path': str(self.socket_path)}")
            return True
        except Exception as e:
            error_msg = str(e)
            self.logger.error(f"Failed to set up socket server {error_msg}")
            return False

    def write_pid_file(self) -> bool:
        try:
            pid = os.getpid()
            self.pid_file.write_text(str(pid))
            self.logger.info("PID file created", {"pid": pid, "path": str(self.pid_file)})
            return True
        except Exception as e:
            error_msg = {'path': str(self.pid_file), 'error': str(e)}
            self.logger.error(f"Failed to create PID file {error_msg}")
            return False

    async def clean_up(self):
        self.logger.info("Starting cleanup")


        for client in self.clients:
            try:
                client.close()
                await client.wait_closed()
            except Exception:
                pass

        if self.server:
            self.server.close()
            await self.server.wait_closed()

        try:
            if self.socket_path.exists():
                self.socket_path.unlink()
        except Exception as e:
            error_msg = str(e)
            self.logger.error(f"Error removing socket file {error_msg}")

        try:
            if self.pid_file.exists():
                self.pid_file.unlink()
        except Exception as e:
            error_msg = str(e)
            self.logger.error(f"Error removing PID file {error_msg}")

        self.logger.info("Service shutdown complete")

    async def start(self):
        if not await self.setup_socket_server():
            self.logger.error("Failed to start service")
            return

        self.logger.info("Socket Server is ready, writing PID file")
        self.write_pid_file()

        loop = asyncio.get_running_loop()

        def signal_handler():
            self.logger.debug("Received shutdown signal")
            asyncio.create_task(self.shutdown())

        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(sig, signal_handler)

        self.logger.debug("Service started successfully")

        async with self.server:
            await self.server.serve_forever()

    async def shutdown(self):
        await self.clean_up()

        loop = asyncio.get_running_loop()
        loop.stop()
