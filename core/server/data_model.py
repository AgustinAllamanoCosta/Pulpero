from typing import Literal
import json

class ServerResponse:

    requestId: int
    result: bool | str | None
    error: str | None

    def __init__(self, requestId: int, result: bool | str | None, error: str | None ) -> None:
        self.requestId = requestId
        self.result = result
        self.error = error

    def __str__(self) -> str:
        response_dict = {
            "requestId": self.requestId,
            "result": self.result,
            "error": self.error
        }
        response_str = json.dumps(response_dict)
        return response_str

class ServerRequest:

    params: dict[str, dict[str, str] | str]
    Id: int
    method: Literal["talk_with_model", "get_live_code_feedback", "prepear_env", "clear_model_cache", "get_download_status", "get_service_status", "toggle"]

    def __init__(self,
                 method: Literal["talk_with_model", "get_live_code_feedback", "prepear_env", "clear_model_cache", "get_download_status", "get_service_status", "toggle"],
                 Id: int,
                 params: dict[str, dict[str, str] | str]) -> None:
        self.method = method
        self.Id = Id
        self.params = params
