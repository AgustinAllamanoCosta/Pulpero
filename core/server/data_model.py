from typing import Literal, Any

class ServerResponse:

    requestId: int
    result: bool | str | None
    error: str | None

    def __init__(self, requestId: int, result: bool | str | None, error: str | None ) -> None:
        self.requestId = requestId
        self.result = result
        self.error = error

class ServerRequest:

    params: Any
    Id: int
    method: Literal["talk_with_model", "get_live_code_feedback", "prepear_env", "clear_model_cache", "get_download_status", "get_service_status", "toggle"]

    def __init__(self,
                 method: Literal["talk_with_model", "get_live_code_feedback", "prepear_env", "clear_model_cache", "get_download_status", "get_service_status", "toggle"],
                 Id: int,
                 params: Any) -> None:
        self.method = method
        self.Id = Id
        self.params = params


