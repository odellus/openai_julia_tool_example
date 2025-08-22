# TRAE.md

Instructions for trae-agent to follow

# INSTRUCTIONS
- using OpenAI.jl write an example of how to use tool calling with julia
- Create a .env with OPENAI_API_KEY=EMPTY and OPENAI_BASE_URL=http://localhost:4000/v1 for example
- use best practices for julia development [is there a uv package manager for julia?] I have no idea what this is

# RULES
- Do your best

# TOOLS

- When you use `str_replace_edit_tool` with the command `create` you must provide the non-optional, required argument `file_text` with the contents of the file you wish to create like so


```python
str_replace_based_edit_tool({
  "path": "/Users/thomas.wood/src/dspy/TRAE_10.md",
  "command": "create"
  "file_text": "[The contents we wish to insert into the file]" # <- REMEMBER
})
```

If you just want to create the file without adding text, use bash tool and `touch` command please.

- Don't hesitate to use the search tools when you are in any way uncertain
