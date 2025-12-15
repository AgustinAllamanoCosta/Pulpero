import os
import json
from datetime import datetime
from typing import Optional, Any

class LoggerConfig:

    def __init__(self, class_name: str) -> None:
        self.directory = "/tmp"
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
{}: {}
Data: {}
----------------------------------------
"""
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                formatted_message = message_template.format(timestamp, message, data_str)
                log_file.write(formatted_message)

                if self.test_env:
                    print(formatted_message.strip())

        except IOError as e:
            if self.test_env:
                print(f"Error writing to log: {e}")

    def _to_string(self, data: Any) -> str:
        """Convert data to string representation (equivalent to String:to_string from Lua)"""
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
