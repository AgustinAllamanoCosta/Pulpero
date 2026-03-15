import os
import json
from datetime import datetime
from typing import Optional, Any

class LoggerConfig:

    directory: str
    class_name: str
    debug_file: str
    setup_file: str
    command_output: str
    error_file: str
    debug_path: str
    error_path: str
    command_path: str
    setup_path: str
    title_setup: str
    title_command: str
    title_error: str
    title_debug: str

    def __init__(self, class_name: str) -> None:
        self.directory = "/tmp"
        self.class_name = class_name
        self.debug_file = f"pulpero_{class_name}_debug.log"
        self.setup_file = f"pulpero_{class_name}_setup.log"
        self.command_output = f"pulpero_{class_name}_command.log"
        self.error_file = f"pulpero_{class_name}_error.log"
        self.debug_path = ""
        self.error_path = ""
        self.command_path = ""
        self.setup_path = ""
        self.title_setup = "=== New SetUp Session Started ===\n"
        self.title_command = "=== New Command Session Started ===\n"
        self.title_error = "=== New Error Session Started ===\n"
        self.title_debug = "=== New Debug Session Started ===\n"

    def __str__(self) -> str:
        return f'''
    directory: {self.directory}
    class_name: {self.class_name}
    debug_file: {self.debug_file}
    setup_file: {self.setup_file}
    command_output: {self.command_output}
    error_file: {self.error_file}
    debug_path: {self.debug_path}
    error_path: {self.error_path}
    command_path: {self.command_path}
    setup_path: {self.setup_path}
    title_setup: {self.title_setup}
    title_command: {self.title_command}
    title_error: {self.title_error}
    title_debug: {self.title_debug}
    '''

class Logger:

    def __init__(self, class_name: str, test_env: bool = False) -> None:
        self.config: LoggerConfig = LoggerConfig(class_name)
        self.configured_logger_path_base_on_OS()
        self.clear_logs()
        self.test_env = test_env

    def get_config(self) -> LoggerConfig:
        return self.config

    def configured_logger_path_base_on_OS(self):
        self.config.directory = self._get_temp_dir()
        self.config.debug_path = self._create_path_by_OS(self.config.directory, self.config.debug_file)
        self.config.error_path = self._create_path_by_OS(self.config.directory, self.config.error_file)
        self.config.command_path = self._create_path_by_OS(self.config.directory, self.config.command_output)
        self.config.setup_path = self._create_path_by_OS(self.config.directory, self.config.setup_file)

    def _get_temp_dir(self) -> str:
        import tempfile
        return tempfile.gettempdir()

    def _create_path_by_OS(self, directory: str, filename: str) -> str:
        return os.path.join(directory, filename)

    def clear_logs(self):
        self.clear_log_file(self.config.debug_path, self.config.title_debug)
        self.clear_log_file(self.config.error_path, self.config.title_error)
        self.clear_log_file(self.config.setup_path, self.config.title_setup)
        self.clear_log_file(self.config.command_path, self.config.title_command)

    def setup(self, message: str, data: Optional[Any] = None):
        self.write_in_log(self.config.setup_path, message, data)

    def debug(self, message: str, data: Optional[Any] = None):
        if self.test_env is True:
            self.write_in_log(self.config.debug_path, message, data)

    def info(self, message: str, data: Optional[Any] = None):
        self.write_in_log(self.config.debug_path, message, data)

    def error(self, error_text: str):
        self.write_in_log(self.config.error_path, error_text, None)

    def command_output(self, output: str, data: Optional[Any] = None):
        self.write_in_log(self.config.command_path, output, data)

    def clear_log_file(self, file_path: str, file_title: str):
        try:
            with open(file_path, "w", encoding='utf-8') as file:
                file.write(file_title)
        except IOError:
            raise ValueError("Logger file cannot be Open")

    def write_in_log(self, path: str, message: str, data: Optional[Any] = None):
        if path is None:
            raise ValueError("Logger path cannot be None")

        data_str = ""
        if data is not None:
            data_str = self._to_string(data)

        try:
            with open(path, "a", encoding='utf-8') as log_file:
                message_template = """
{}
{}: {}
Data: {}
----------------------------------------
"""
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                formatted_message = message_template.format(self.config.class_name, timestamp, message, data_str)
                log_file.write(formatted_message)

                if self.test_env:
                    print(formatted_message.strip())

        except IOError as e:
            if self.test_env:
                print(f"Error writing to log: {e}")

    def _to_string(self, data: Any) -> str:
        if isinstance(data, dict):
            try:
                return json.dumps(data, indent=2, default=str)
            except (TypeError, ValueError):
                return str(data)
        elif isinstance(data, (list, tuple)):
            try:
                return json.dumps(data, indent=2, default=str)
            except (TypeError, ValueError):
                return str(data)
        else:
            return str(data)
