import re
from typing import List

from core.util.logger import Logger

class Parser:

    def __init__(self, logger: Logger) -> None:
        self.logger = logger

    def clean_model_output(self, output: str) -> str:
        clean_response = ""
        in_assistant_response = False
        skip_line = False
        response_lines = []

        if output is None:
            return clean_response

        for line in output.splitlines():

            if re.search(r"Current open file code:|Chat History", line):
                skip_line = True
                continue

            if (re.search(r"End File|End History", line)) and skip_line:
                skip_line = False
                continue

            if skip_line:
                continue


            if re.search(r"A:", line):
                in_assistant_response = True

                cleaned_line = re.sub(r"A:", "", line)
                cleaned_line = re.sub(r"\[end of text\]", " ", cleaned_line)
                response_lines.append(cleaned_line + "\n")
                continue

            if in_assistant_response:
                if line != "" and not re.search(r"<｜end▁of▁sentence｜>", line):

                    clean_line = re.sub(r"\[INST\]", "", line)
                    clean_line = re.sub(r"\[/INST\]", "", clean_line)
                    clean_line = re.sub(r"\[end of text\]", " ", clean_line)
                    response_lines.append(clean_line + "\n")

        if len(response_lines) > 0:
            clean_response = "\n".join(response_lines)

        self.logger.debug("parse complete", {"lines": len(clean_response)})
        return clean_response

    def get_code_from_response(self, output: str) -> List[str]:
        in_code = False
        code_lines = []

        for line in output.splitlines():
            if re.search(r"```\s*", line) and not in_code:
                in_code = True
                continue

            if re.search(r"```", line) and in_code:
                in_code = False
                continue

            if in_code:
                if line != "":
                    code_lines.append(line + "\n")

        self.logger.debug("Code parse", {"code_lines": len(code_lines)})
        return code_lines
