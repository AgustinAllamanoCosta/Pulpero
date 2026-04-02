import os
from pathlib import Path

class OSCommands:
    @classmethod
    def get_model_dir(cls):
        source_path = cls.get_data_path()
        final_path = source_path / "model"
        final_path.mkdir(parents=True, exist_ok=True)
        return final_path

    @staticmethod
    def get_data_path():
        home = Path.home()
        if os.name == 'nt':
            return Path(os.getenv('APPDATA', home)) / 'pulpero'
        else:
            return home / '.local' / 'share' / 'pulpero'


