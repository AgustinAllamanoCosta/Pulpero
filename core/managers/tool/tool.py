class Tool:

    def __init__(self, name: str, description: str, parameters: dict, example: str, callback) -> None:
        self.name = name
        self.description = description
        self.parameters = parameters
        self.example = example
        self.execute = callback
