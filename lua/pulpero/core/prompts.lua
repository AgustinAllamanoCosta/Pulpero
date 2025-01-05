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
You are a Sr developer. Respond ONLY with the refactored code. Do not add any explanation or text outside the code block.</s>
<|user|>
%s code:
%s</s>
<|assistant|>
]]
prompts = {
    explain_prompt = explain_prompt,
    refactor_prompt = refactor_prompt,
}

return prompts
