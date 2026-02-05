#!/usr/bin/env bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Generate a unique completion marker
COMPLETION_MARKER="COMPLETION_MARKER_$(date +%s%N | sha256sum | head -c 32)"

# Help function
show_help() {
    cat << EOF
Usage: ralph.sh <requirements-file> <backlog-file> [iterations-limit] [agent-model] [workspace-path]

Ralph loop implemented with Cursor CLI.

Arguments:
    requirements-file  Path to requirements markdown file (required, must end with .md)
    backlog-file       Path to backlog JSON file (required, must end with .json)
    iterations-limit   Maximum number of iterations to run (optional, default: 1)
    agent-model        AI model to use (optional, default: subscription default)
    workspace-path     Path to project/workspace root (optional, default: ..).
                       Use this so the Cursor CLI knows the root of the project.

Examples:
    ralph.sh requirements.md PRD.json
    ralph.sh requirements.md PRD.json 5
    ralph.sh requirements.md backlog/PRD-02.json 20 opus-4.5-thinking
    ralph.sh requirements.md PRD.json 3 opus-4.5 /home/user/projects/my-project
    ralph.sh --help

EOF
    exit 0
}

# Print configuration recap and wait for user confirmation
print_config_recap() {
    echo -e "${GREEN}===========================================${NC}"
    echo -e "${GREEN}Ralph Loop${NC}"
    echo -e "${GREEN}===========================================${NC}"
    echo -e "${YELLOW}Configuration:${NC}"
    echo "  Requirements file: $REQUIREMENTS_FILE"
    echo "  Backlog file:      $BACKLOG_FILE"
    echo "  Iterations limit:  $ITERATIONS_LIMIT"
    echo "  Agent model:       $MODEL_DISPLAY"
    echo "  Workspace (root):  $WORKSPACE_ABS"
    echo "  Completion marker: $COMPLETION_MARKER"
    echo -e "${GREEN}===========================================${NC}"
}

# Print configuration recap as result of the loop
# Usage: print_exit_config_recap [status-message] [iteration-reached] [end-time]
print_exit_config_recap() {
    local status_msg="$1"
    local iteration_reached="$2"
    local end_time="$3"
    print_config_recap
    echo "  RESULT:"
    echo "==========================================="
    echo -e "  Status:            $status_msg"
    echo "  Iteration reached: $iteration_reached"
    echo "  Start time:        $LOOP_START_TIME"
    echo "  End time:          $end_time"
    echo ""
}

# Check for help flag
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_help
fi

# Validate required parameters
if [ -z "$1" ]; then
    echo -e "${RED}Error: requirements-file is required${NC}"
    echo "Run 'ralph.sh --help' for usage information"
    exit 1
fi

if [ -z "$2" ]; then
    echo -e "${RED}Error: backlog-file is required${NC}"
    echo "Run 'ralph.sh --help' for usage information"
    exit 1
fi

# Parse arguments
REQUIREMENTS_FILE=$1
BACKLOG_FILE=$2
ITERATIONS_LIMIT=${3:-1}
AGENT_MODEL=${4:-""}
WORKSPACE_PATH=${5:-".."}

# Validate workspace path exists
if [ ! -d "$WORKSPACE_PATH" ]; then
    echo -e "${RED}Error: workspace-path '$WORKSPACE_PATH' does not exist or is not a directory${NC}"
    exit 1
fi

# Resolve workspace path to absolute so the agent has a clear project root
WORKSPACE_ABS=$(cd "$WORKSPACE_PATH" && pwd)

# Validate requirements file has .md extension
if [[ ! "$REQUIREMENTS_FILE" =~ \.md$ ]]; then
    echo -e "${RED}Error: requirements-file must have .md extension${NC}"
    exit 1
fi

# Validate requirements file exists
if [ ! -f "$REQUIREMENTS_FILE" ]; then
    echo -e "${RED}Error: requirements-file '$REQUIREMENTS_FILE' does not exist${NC}"
    exit 1
fi

# Validate backlog file has .json extension
if [[ ! "$BACKLOG_FILE" =~ \.json$ ]]; then
    echo -e "${RED}Error: backlog-file must have .json extension${NC}"
    exit 1
fi

# Validate backlog file exists
if [ ! -f "$BACKLOG_FILE" ]; then
    echo -e "${RED}Error: backlog-file '$BACKLOG_FILE' does not exist${NC}"
    exit 1
fi

# Validate iterations limit is a number
if ! [[ "$ITERATIONS_LIMIT" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: iterations-limit must be a positive integer${NC}"
    exit 1
fi

# Build model parameter
MODEL_PARAM=""
MODEL_DISPLAY="Your subscription default"
if [ -n "$AGENT_MODEL" ]; then
    MODEL_PARAM="--model $AGENT_MODEL"
    MODEL_DISPLAY="$AGENT_MODEL"
fi

# Display recap
print_config_recap
echo ""
read -p "Press Enter to start or Ctrl+C to cancel..."
echo ""

LOOP_START_TIME=$(date "+%Y-%m-%d %H:%M:%S")
echo "Starting at $LOOP_START_TIME"
echo ""

# Main iteration loop
for ((i=1; i<=$ITERATIONS_LIMIT; i++)); do
    CURR_ITERATION_START_TIME=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${YELLOW}Iteration $i/$ITERATIONS_LIMIT${NC} (${CURR_ITERATION_START_TIME})"
    echo "_______________________"

    result=$(
      agent --force $MODEL_PARAM --workspace "$WORKSPACE_ABS" -p <<EOF
@$REQUIREMENTS_FILE @$BACKLOG_FILE @progress.txt

GLOBAL RULES (NON-NEGOTIABLE)
- Work on EXACTLY ONE feature per run.
- Do NOT start a second feature under any circumstance.
- All tests MUST be green before you stop.
- Tests must NEVER be removed, skipped, weakened, or modified to make them pass.
- If tests are red, you must fix the implementation until they are green.
- If you cannot make tests green for the selected feature, STOP and explain why.

PROCESS
1. Read and fully understand:
   - The requirements file
   - The backlog JSON file
   - The current progress.txt

2. Feature selection:
   - From the backlog JSON, identify all features where "passes": false.
   - Choose the SINGLE highest-priority feature to implement.
     Priority is determined by:
       a) Core functionality over enhancements
       b) Dependencies required by other features
       c) Risk of blocking future work
   - Do NOT implement more than one JSON element.
   - Do NOT add tests other than the ones that are already in the backlog JSON.

THINKING TRACE (MANDATORY)
- As soon as you decide which feature to implement, you MUST create a file named "thinking.tmp".
- The file MUST be created immediately after feature selection and before any code changes.

The initial contents of "thinking.tmp" MUST include:
- Date and time of initialization
- Identifier / name of the chosen feature

During the iteration:
- Append ONLY extremely minimal notes for important decisions/struggles.
- Each entry should be a single short line.
- Do NOT include verbose reasoning or explanations.
- The purpose is that running "cat thinking.tmp" clearly shows what you are currently working on.

Completion rules:
- Once the feature is fully implemented, tests are green, progress.txt is updated, and the git commit is created:
    - You MUST delete "thinking.tmp".
- The file must NOT exist at the end of a successful iteration.
- Leaving "thinking.tmp" behind is considered an incomplete run.

3. Implementation:
   - Implement ONLY the selected feature.
   - Do not refactor unrelated code.
   - Do not introduce speculative improvements.
   - Do not touch future or optional features.

4. Validation (EXECUTION-ONLY):
   - Build the project.
   - Run the specific test for the feature, then run the full suite.
   - All tests MUST pass.
   - If tests fail, fix the implementation and re-run tests until green.
   - If you cannot make tests green fixing the implementation, STOP and explain why.

5. Completion of the feature:
   - Update ONLY the implemented feature in the backlog JSON:
       "passes": true
   - Do not modify other features.

6. Progress logging:
   - APPEND a new entry to progress.txt including:
       - Date and time
       - Feature name / identifier
       - Brief description of what was done
       - Confirmation that tests are green

7. Version control:
   - Create a git commit for this feature only.
   - Follow the Conventional Commits specification (eg. feat, fix, docs, style, refactor, chore, test, perf, etc.).
   - The commit must correspond exactly to the implemented feature.

EXIT CONDITION (CRITICAL)
- After updating the backlog JSON, re-check it.
- If ALL features in the JSON have "passes": true:
     - Output the EXACT string below on a line by itself and NOTHING ELSE:

     $COMPLETION_MARKER

- If at least one feature still has "passes": false:
     - STOP immediately.
     - Do NOT continue to another feature.
     - Do NOT output the completion marker.
EOF
    )   
  

    echo "$result"
    
    if [[ "$result" == *"$COMPLETION_MARKER"* ]]; then
        END_TIME=$(date "+%Y-%m-%d %H:%M:%S")
        print_exit_config_recap "${GREEN}✅ Completed${NC}" $i $END_TIME
        exit 0
    fi
done

END_TIME=$(date "+%Y-%m-%d %H:%M:%S")
print_exit_config_recap "${YELLOW}⚠️ Max iterations reached${NC}" $((i-1)) $END_TIME
exit 0