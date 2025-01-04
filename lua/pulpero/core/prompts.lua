local prompts = {}

local explain_prompt = [[
<|system|>
You are a code explanation expert. Provide concise, non-repetitive explanations focusing on the key functionality.</s>
<|user|>
Explain this %s function:

%s</s>
<|assistant|>]]

local refactor_prompt = [[
<|system|>
You are a sr developer. Analyze this code and provide a refactor of it.</s>
<|user|>
Refactor this %s code:

%s</s>
<|assistant|>]]


prompts = {
    explain_prompt = explain_prompt,
    refactor_prompt = refactor_prompt,
}

return prompts
