import re
from typing import List

from core.util.logger import Logger

class Parser:

    def __init__(self, logger: Logger) -> None:
        self.logger = logger

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
