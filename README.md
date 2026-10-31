# EduAssist LLMOps Lab: API Cost, Latency and Prompt Version Management

MLOps Experiential Learning Assignment-2. One notebook (`eduassist_llmops.ipynb`) covers all three tasks:

| Task | Marks | What the notebook does |
|---|---|---|
| 1 | 2 | Calls the model for 5 academic questions, records latency, summary statistics, interpretation |
| 2 | 3 | Token usage, cost per request, monthly projection for 10,000 requests, one cost recommendation |
| 3 | 5 | MLflow experiment `eduassist_llmops_assignment`, Prompt Registry v1/v2/v3, 5 metrics per version, `production` alias, justification |

## Model, pricing and versions (as required by the academic-integrity section)

- **Model:** `Qwen/Qwen2.5-1.5B-Instruct`, a locally hosted open-source model run on CPU with Hugging Face `transformers` (no paid API was used; the assignment allows this when API access is unavailable).
- **Tokens:** counted with the model's own tokenizer (input tokens include the chat-template tokens). Decoding is greedy (temperature 0) and `max_new_tokens = 256` for every request.
- **Cost:** a local model has no bill, so cost is estimated from a published hosting price for the same model: **0.10 USD per 1M input tokens and 0.10 USD per 1M output tokens**, retrieved 2026-10-31 (source page last updated 2026-07-21). Source: https://pricepertoken.com/pricing-page/model/qwen-qwen2.5-1.5b-instruct (cross-checked with the Fireworks listing on getmaxim.ai). **Currency: USD.**
- **"API version":** there is no API; the exact library versions and model revision are printed by the notebook and are the reproducibility record.
- **Secrets:** nothing is hard-coded. No API key is needed. `HF_TOKEN` is read from the environment only if you set it.

## Environment

- **Python:** 3.12 (lab VM: 3.12.9; also tested on 3.13)
- **Libraries** (`requirements.txt`): `mlflow>=3.17,<4` (Prompt Registry needs MLflow 3.x), `transformers>=5.0,<6`, `torch>=2.4` (CPU build is fine), `pandas>=2.2`
- **Environment variables (all optional):**
  - `HF_TOKEN`: Hugging Face token (not needed for this public model)
  - `EDUASSIST_MODEL`: override the model id (if you change it, also update the price settings in the config cell)
- **Hardware used for the run:** 4 CPU cores, 15 GB RAM, no GPU. Model download is about 3 GB.

## Installation

```bash
git clone https://github.com/shankarece/eduassist-llmops-lab.git ~/workspace/eduassist-llmops-lab
cd ~/workspace/eduassist-llmops-lab
python -m pip install torch --index-url https://download.pytorch.org/whl/cpu   # optional: smaller CPU-only PyTorch
python -m pip install -r requirements.txt
```

(The notebook's first cell also installs anything missing, so this step is optional.)

### Quick run on the lab VM (one script)

```bash
bash run_lab.sh        # pre-flight checks, isolated .venv, runs the notebook, exports HTML
bash run_lab.sh ui     # starts the MLflow UI afterwards
```

The script does the same steps as the manual instructions below and needs no Jupyter or browser to run the notebook.

## Steps to reproduce

1. Open `eduassist_llmops.ipynb` in Jupyter, from inside the cloned folder (so `mlflow.db` and the CSVs are written next to the notebook).
2. **Run All Cells.** It loads the model, does a short warm-up, then makes 20 generations (5 for Task 1/2 + 15 for Task 3). This takes roughly 15-30 minutes on a 4-core CPU.
3. Outputs written to the folder: `latency_tokens_cost.csv`, `prompt_evaluation_results.csv`, and the MLflow store `mlflow.db`.
4. Start the MLflow UI **from the same folder**:
   ```bash
   mlflow ui --backend-store-uri sqlite:///mlflow.db
   ```
   and open http://127.0.0.1:5000 in a browser.
5. Take the screenshots listed below and save them in `screenshots/`.
6. Optional HTML export of the executed notebook:
   ```bash
   jupyter nbconvert --to html eduassist_llmops.ipynb
   ```

## MLflow screenshots (MLflow 3.17 UI)

Close the "MLflow Assistant" side panel (X) and any "Got it" pop-up first.

| File name | Where |
|---|---|
| `01_experiment_runs.png` | Experiment `eduassist_llmops_assignment`, top-left toggle **Model training** -> **Runs**: shows `prompt_v1`, `prompt_v2`, `prompt_v3` |
| `02_metrics.png` | Same Runs page: **Columns** -> tick the 5 metrics so they appear as columns (or select the 3 runs and click **Compare**) |
| `03_prompt_registry.png` | Toggle **GenAI** -> **Prompts** -> `eduassist_qa_prompt`: versions 1, 2, 3 listed |
| `04_prompt_diff.png` | Same page, **Compare** tab, select two versions, switch the view to **Text** to see the differences |
| `05_production_alias.png` | Same page, **Preview** tab: the `@ production` alias on the promoted version |

## Files

| File | Purpose |
|---|---|
| `eduassist_llmops.ipynb` | Notebook with executable code for Tasks 1-3 |
| `requirements.txt` | Python dependencies |
| `run_lab.sh` | Helper script that automates install + run + HTML export on the lab VM |
| `latency_tokens_cost.csv` | Tasks 1 and 2: per-request latency, tokens, cost (5 requests, Prompt v1) |
| `prompt_evaluation_results.csv` | Task 3: per-response results for v1, v2, v3 (15 rows) |
| `screenshots/` | MLflow screenshots |
| `report.pdf` | Final report (500-700 words) |
