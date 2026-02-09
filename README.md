# cursor-ralph-loop

Bash implementation of the [Ralph loop](https://ghuntley.com/ralph/) (agent-in-a-while-loop) using the **Cursor CLI**.

Usable if you already have a Cursor subscription.

A deeper look into it: [Use case and walkthrough](https://borgoo.github.io/blog/posts/cursor-ralph-loop.html). 

## Dependencies & Docker

- **Dependencies:** Bash, Cursor CLI (installed inside the image), git, build-essential, curl, wget.
- A **Dockerfile** is provided; the setup is used on Windows and intended to run inside **Docker** as a sandbox for the project.

## Files

| File | Role |
|------|------|
| **PRD.json** | Product requirements / backlog: deterministic, test-oriented, as exhaustive as possible <br>Defines features to implement |
| **requirements.md** | Informal project guidelines |
| **ralph.sh** | Core script <br>Run `./ralph.sh` <br>see usage with `./ralph.sh --help` |

```
Usage: ralph.sh <requirements-file> <backlog-file> [iterations-limit] [agent-model] [workspace-path]
Arguments:
  requirements-file  Path to requirements markdown (required, .md)
  backlog-file       Path to backlog JSON (required, .json)
  iterations-limit   Max iterations (optional, default: 1)
  agent-model        AI model (optional, default: subscription default)
  workspace-path     Project/workspace root (optional, default: ..). Helps Cursor CLI know the project root.
Example: ./ralph.sh requirements.md backlogs/PRD.json 5
```

### You must use your own project files

**Edit `PRD.json` and `requirements.md` before running Ralph for your project.**

The ones in this repo are only **examples** for a minimal CRUD C23 library CLI. Replace them with your backlog and guidelines;

keep the **PRD.json structure** (category, description, steps, passes).

You can also edit the prompt inside **ralph.sh** (e.g. other languages or patterns to avoid for your project).

## First-time setup: authenticate the agent

Run the Cursor agent command in the terminal and complete the **browser login** so the CLI can use your subscription.

Do this before running `./ralph.sh`.

## How to run

This code is meant to live as a **subdirectory of your project**, not as the project itself.

From your **project root**, create the `ralph-loop` directory without versioning (no nested git):

*Linux*:
```bash
git clone --depth 1 https://github.com/borgoo/cursor-ralph-loop.git cursor-ralph && rm -rf cursor-ralph/.git
```

*Windows*:
```bash
git clone --depth 1 https://github.com/borgoo/cursor-ralph-loop.git && rmdir /s /q cursor-ralph-loop\.git
```


(optional) Build an image from the Dockerfile and run a container with your project mounted (e.g. `docker build -t ralph .` then `docker run -it -v /path/to/your-project:/workspace ralph`). Inside the container, run `./ralph.sh` from the `ralph-loop` directory.



## Generated files (during run)

- **progress.txt** — History of what each iteration did; useful to review progress.

## Troubleshooting

- **Run the agent before `./ralph.sh`** — Ensure the Cursor agent is started and logged in so the CLI can reach the models.
- **Models** — See the [Cursor CLI documentation](https://cursor.com/docs/cli/overview#getting-started) for available models (`agent models` in terminal) and how to pass them (e.g. `agent-model` argument).
- **Incorrect line endings** — If an error like this appears in the terminal when running `./ralph.sh`
  ```
  /usr/bin/env: 'bash\r': No such file or directory
  /usr/bin/env: use -[v]S to pass options in shebang lines
  ```

  Change CLRF to LF line endings in `ralph.sh` file.
