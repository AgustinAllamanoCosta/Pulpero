import os
from core.main import OSCommands
from core.runner.model.model_runner import RunnerConfig
from core.util.logger import Logger
import tempfile
import requests
import tarfile
import hashlib
import json

chunks_info = [
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-1.tar.gz",
        "checksum": "d0d6252996fccb5b62a3ba0fbc61562d3e2e1944f9ac795b3fa63ae4b217db1d"
    },
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-2.tar.gz",
        "checksum": "97ab32f374850a97e9684e8037269c3c9735163bee18213e59a30dd3d8e289ac"
    },
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-3.tar.gz",
        "checksum": "57fb74a59e4605743df3bb30e6b50990dafd84e76fe800a7083851f2255740d8"
    },
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-4.tar.gz",
        "checksum": "4e85d81105560049b059a7da56910fab62da104d8d62b875acb1569c4cf6e0c2"
    },
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-5.tar.gz",
        "checksum": "e583a99e45a19b6eb46281ce32cedeb9f0fed1e990eecdc3ca7de53b2506f853"
    },
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-6.tar.gz",
        "checksum": "f6a930387692184faf15f4ef39ff79ce247d3e6532d52a508d7a7cfa088222a3"
    },
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-7.tar.gz",
        "checksum": "24fa877645aa5993e7d2fb55423e03531c90eded60d0fdf4fcf560bbbcef5153"
    },
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-8.tar.gz",
        "checksum": "9aa335732d2556cb3dd580299bc0c0b4a9973e81acb8ef9f137baf63c12ee15c"
    },
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-9.tar.gz",
        "checksum": "82b3284afb2bce6694a8c7c42d730390c2acb6cd6df0f1e6334915c03fd6fb92"
    },
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-10.tar.gz",
        "checksum": "dc83b84fdd1053987f80cec25340d447f7550c8cb24f373e2fff2cfa9866de55"
    },
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-11.tar.gz",
        "checksum": "9a33572396e50300c7b8026dfb0c9408c8941d132bbe4c2956276e0f302b5bb9"
    },
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-12.tar.gz",
        "checksum": "2073861a3e41aba20131eb0fd0a8ca8cc1f2afc3dd7926dfe237c640153b59db"
    },
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-13.tar.gz",
        "checksum": "3b676e233d99c42ecf0a877dbe5cb520f85adb5f8452901c9adda1dff7de8c06"
    },
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-14.tar.gz",
        "checksum": "e6338df01c03816ea8b7650fa08566ee8a5867735e473c4de6417abb48a89bd1"
    },
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-15.tar.gz",
        "checksum": "6326cbbf084970bf77a6ac8006bd3008bb98c106272422301a02c4cd717ea68b"
    },
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-16.tar.gz",
        "checksum": "013766b03f4c4b425cb4d9014b777b2e2ad9d7a5d057452b741c50e4010af2d0"
    },
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-17.tar.gz",
        "checksum": "b5411f9c2d0e806e57bd77490062385dad31ed24a5f3e5a9b8ec127bcaec54a3"
    },
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-18.tar.gz",
        "checksum": "89a39fcc307d7e30dabcec36ceefa984ed29f6cbd0736510a32d81f20bcbe746"
    },
    {
        "url": "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-19.tar.gz",
        "checksum": "d2fab1cb51d3f4106a083d4a3dc8c09b2b1eb4c43a18f45ea137589e4fc994b5"
    }
]

status = {
    "current_chunk": 0,
    "total_chunks": len(chunks_info),
    "state": "downloading",
    "error": "",
    "downloaded_chunks": [],
    "extracted_chunks": []
}

class ModelManager:

    def __init__(self, logger: Logger | None, default_config: RunnerConfig) -> None:
        if logger is None:
            raise ValueError("ModelManager logger can not be nil")
        self.logger = logger
        self.config = {
            "temp_dir": tempfile.gettempdir(),
            "model_dir": OSCommands.get_model_dir(),
            "model_path": default_config.model_path,
            "all_chunk_download": False,
            "status_file": os.path.join(tempfile.gettempdir(), "pulpero_download_status.txt"),
            "model_assemble": False
        }

        if os.path.exists(self.config['status_file']) == False:
            self.write_status(self.config['status_file'], status)

    def write_status(self, status_file: str, status: dict) -> None:
        with open(status_file, 'w') as f:
            json.dump(status, f)
            f.close()

    def get_status_from_file(self) -> str:
        self.logger.debug(f"Get model status from file path { 'path': self.config.status_file }")
        if os.path.exists(self.config['status_file']) == True:
            with open(self.config['status_file'], 'r') as f:
                response = json.load(f)
                f.close()
                status['state'] = response['state']
        else:
            self.check_if_model_exist()
        self.logger.debug(f"State {status['state']}")
        return status['state']

    def download_chunk(self, chunk_url: str, output_file: str) -> int:
        response = requests.get(chunk_url, verify=False)
        with open(output_file, "wb") as file:
            file.write(response.content)
        return response.status_code

    def verify_checksum(self, file_path: str, expected_checksum: str) -> bool:
        calculated_checksum: str
        with open(file_path, 'rb') as f:
            hashfile = hashlib.sha256()
            hashfile.update(f.read())
            calculated_checksum = hashfile.hexdigest()
            f.close()
        result: bool = calculated_checksum == expected_checksum
        return result

    def extract_chunk(self, chunk_file, chunk_number: int, temp_dir: str) -> bool:
        self.logger.debug("Extract command to excute {extract_cmd}", chunk_number)
        tar = tarfile.open(chunk_file, "r:gz")
        tar.extractall(path=temp_dir)
        tar.close()
        expected_name = f"deepseek.part-{chunk_number}"
        expected_path = os.path.join(temp_dir, expected_name)
        if os.path.exists(expected_path) == True:
            return True
        else:
            self.logger.debug(f"extracted file does not exit {expected_path}")
            return False

    def assemble_model(self, temp_dir: str, model_path: str, num_chunks: int) -> bool:
        if os.path.exists(model_path) == False:
            return False
        with open(model_path, "wb") as file:
            for i in range(0, num_chunks):
                chunk_path = os.path.join(temp_dir, f"deepseek.part-{i}")
                if os.path.exists(chunk_path) == False:
                    file.close()
                    return False
                else:
                    chunk_file = open(chunk_path, "rb")
                    chunk_data = chunk_file.read()
                    file.write(chunk_data)
                    chunk_file.close()
                    os.remove(chunk_path)
            file.close()
            return True

    def check_if_model_exist(self) -> bool:
        self.logger.debug(f"Checking if file exist {self.config['model_path']}")
        file = os.path.exists(self.config['model_path'])
        if file:
            status['state'] = "completed"
            self.write_status(self.config['status_file'], status)
        self.logger.debug(f"Check finished status is: {status}")
        return file

    def download_and_assemble_model(self) -> None:
        self.logger.debug("Starting background model download")

        for i in range(0, len(chunks_info)):
            status['current_chunk'] = i
            status['state'] = "downloading"
            self.write_status(self.config['status_file'], status)

            temp_file = os.path.join(self.config['temp_dir'], f"model_chunk_{i}.tar.gz")

            chunk_info = chunks_info[i]
            if self.download_chunk(chunk_info['url'], temp_file):

                if self.verify_checksum(temp_file, chunk_info['checksum']):
                    status['downloaded_chunks'].append(i)
                    self.write_status(self.config['status_file'], status)
                    status['state'] = "extracting"
                    self.write_status(self.config['status_file'], status)
                    if self.extract_chunk(temp_file, i, self.config['temp_dir']):
                        status['extracted_chunks'].append(i)
                        os.remove(temp_file)
                    else:
                        status['state'] = "error"
                        status['error'] = f"Failed to extract chunk {i}"
                        self.write_status(self.config['status_file'], status)
                        raise ValueError(status['error'])
                else:
                    status['state'] = "error"
                    status['error'] = f"Checksum verification failed for chunk {i}"
                    self.write_status(self.config['status_file'], status)
                    os.remove(temp_file)
                    raise ValueError(status['error'])
            else:
                status['state'] = "error"
                status['error'] = f"Failed to download chunk {i}"
                self.write_status(self.config['status_file'], status)
                raise ValueError(status['error'])

        status['state'] = "assembling"
        self.write_status(self.config['status_file'], status)

        if self.assemble_model(self.config['temp_dir'], self.config['model_path'], status['total_chunks']):
            status['state'] = "completed"
        else:
            status['state'] = "error"
            status['error'] = "Failed to assemble model"

        self.write_status(self.config['status_file'], status)

