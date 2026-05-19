# Instructions for Pi

When the user asks a question, requests an opinion, or asks "should we/is it worth it", **do not automatically implement the change**.

Instead:
1. Analyze the context and the problem.
2. Present the pros and cons (or options) to the user.
3. Wait for the user to make a decision or explicitly instruct you to proceed with the implementation.
4. Only edit the codebase after the user agrees to the plan.

## Code Search (Semble)

You have `semble` installed globally. It is an agent-optimized semantic search tool that uses ~98% fewer tokens than `grep`+`read`. Use it when exploring codebases to save context, but fall back to standard tools (grep/find) for system troubleshooting, log files, or simple exact string matching.

Use `semble search` to find code by describing what it does or naming a symbol/identifier, instead of grep:

```bash
semble search "authentication flow" ./my-project
semble search "save_pretrained" ./my-project
semble search "save model to disk" ./my-project --top-k 10
```

Use `semble find-related` to discover code similar to a known location (pass `file_path` and `line` from a prior search result):

```bash
semble find-related src/auth.py 42 ./my-project
```

`path` defaults to the current directory when omitted; git URLs are accepted.

### Workflow
1. Start with `semble search` to find relevant chunks.
2. Inspect full files only when the returned chunk is not enough context.
3. Optionally use `semble find-related` with a promising result's `file_path` and `line` to discover related implementations.
4. Use grep only when you need exhaustive literal matches or quick confirmation of an exact string.