#!/usr/bin/env bash
# One-step helper for the lab VM.
#   bash run_lab.sh      -> checks, creates an isolated environment, runs the notebook, exports HTML
#   bash run_lab.sh ui   -> starts the MLflow UI (open http://127.0.0.1:5000 in the browser)
#   bash run_lab.sh push -> logs in to GitHub (device code) and pushes the result files
set -u
cd "$(dirname "$0")"
VENV=.venv

if [ "${1:-}" = "ui" ]; then
  [ -x "$VENV/bin/mlflow" ] || { echo "Run 'bash run_lab.sh' first."; exit 1; }
  [ -f mlflow.db ] || { echo "mlflow.db not found - the notebook has not been run yet."; exit 1; }
  exec "$VENV/bin/mlflow" ui --backend-store-uri sqlite:///mlflow.db
fi

if [ "${1:-}" = "push" ]; then
  echo "== Sending results to GitHub =="
  GH=$(command -v gh || true)
  [ -z "$GH" ] && [ -x .ghenv/bin/gh ] && GH="$PWD/.ghenv/bin/gh"
  if [ -z "$GH" ]; then
    echo "Installing the GitHub CLI (a few minutes)..."
    conda create -y -q -p .ghenv -c conda-forge gh || { echo "FAIL: could not install the GitHub CLI"; exit 1; }
    GH="$PWD/.ghenv/bin/gh"
  fi
  if ! "$GH" auth status >/dev/null 2>&1; then
    echo "A code like ABCD-1234 will appear. On YOUR computer open https://github.com/login/device , type the code and approve."
    "$GH" auth login --hostname github.com --git-protocol https --web || { echo "FAIL: GitHub login did not complete"; exit 1; }
  fi
  "$GH" auth setup-git
  login=$("$GH" api user --jq .login) && uid=$("$GH" api user --jq .id) || { echo "FAIL: could not read GitHub account"; exit 1; }
  ID=(-c "user.name=$login" -c "user.email=${uid}+${login}@users.noreply.github.com")
  for f in latency_tokens_cost.csv prompt_evaluation_results.csv eduassist_llmops.ipynb eduassist_llmops.html mlflow.db screenshots; do
    [ -e "$f" ] && git add "$f"
  done
  git "${ID[@]}" commit -q -m "Add notebook run results" || echo "(nothing new to commit)"
  git "${ID[@]}" pull --rebase --autostash -q origin main || { echo "FAIL: could not sync with GitHub"; exit 1; }
  git push origin main && echo "PUSHED to https://github.com/shankarece/eduassist-llmops-lab" || { echo "FAIL: push was rejected"; exit 1; }
  exit 0
fi

echo "== 1/4 Pre-flight checks =="
command -v python >/dev/null || { echo "FAIL: python not found"; exit 1; }
python --version
avail=$(df -BG . | awk 'NR==2{gsub("G","",$4); print $4}')
mem=$(free -g | awk '/Mem:/{print $7}')
echo "Free disk: ${avail} GB | Available memory: ${mem} GB"
[ "${avail:-0}" -ge 8 ] || { echo "FAIL: need at least 8 GB free disk"; exit 1; }
[ "${mem:-0}" -ge 8 ] || { echo "FAIL: need at least 8 GB available memory"; exit 1; }
curl -sI -m 20 https://pypi.org | head -1 | grep -q " 200" || { echo "FAIL: cannot reach pypi.org"; exit 1; }
if [ -n "${EDUASSIST_MODEL:-}" ] && [ -d "${EDUASSIST_MODEL}" ]; then
  echo "Using local model folder: ${EDUASSIST_MODEL}"
else
  curl -sI -m 20 https://huggingface.co | head -1 | grep -q " 200" || { echo "FAIL: cannot reach huggingface.co"; exit 1; }
fi
echo "Pre-flight OK"

echo "== 2/4 Creating isolated environment and installing libraries (a few minutes) =="
[ -x "$VENV/bin/python" ] || python -m venv "$VENV" || { echo "FAIL: could not create the environment"; exit 1; }
"$VENV/bin/python" -m pip install -q --upgrade pip
# CPU-only PyTorch is much smaller; if its download site is unreachable, fall back to the normal package.
"$VENV/bin/python" -m pip install -q torch --index-url https://download.pytorch.org/whl/cpu --retries 1 --timeout 20 \
  || "$VENV/bin/python" -m pip install -q torch || { echo "FAIL: torch install failed"; exit 1; }
"$VENV/bin/python" -m pip install -q -r requirements.txt nbconvert ipykernel || { echo "FAIL: library install failed"; exit 1; }
"$VENV/bin/python" -c "import mlflow, transformers, torch, pandas; print('mlflow', mlflow.__version__, '| transformers', transformers.__version__, '| torch', torch.__version__)" || exit 1

echo "== 3/4 Running the notebook (about 15-30 min; a message appears every minute) =="
export PATH="$PWD/$VENV/bin:$PATH"
( while true; do sleep 60; echo "   ...still running, $((SECONDS/60)) min elapsed"; done ) &
HB=$!
jupyter nbconvert --to notebook --execute eduassist_llmops.ipynb --inplace --ExecutePreprocessor.timeout=-1
rc=$?
kill $HB 2>/dev/null
if [ $rc -ne 0 ]; then
  echo "FAILED while running the notebook. Take a photo of the error above and send it."
  exit 1
fi

echo "== 4/4 Exporting HTML =="
jupyter nbconvert --to html eduassist_llmops.ipynb

echo
echo "DONE. Files created:"
ls -l latency_tokens_cost.csv prompt_evaluation_results.csv mlflow.db eduassist_llmops.html
echo
echo "Next: run   bash run_lab.sh ui   then open http://127.0.0.1:5000 for the screenshots."
