# Reproducing the analysis

## Prerequisites

- R (recent version) and RStudio (recommended).
- Internet access for initial package installation and the first English UDPipe model download.
- Dataset: [Zenodo record 18723813](https://zenodo.org/records/18723813). The code expects `data/raw/yelp_sentiment_master_dataset.csv` with review text (`text`), stars (`stars_review`), restaurant name (`name`), and city (`city`). The provided file also contains additional columns.

## Setup and run

1. Open `Customer_Reviews_Course.Rproj` in RStudio. The project root should be your current working directory.
2. Place the **unmodified CSV** at `data/raw/yelp_sentiment_master_dataset.csv` (not included in the repository).
3. Run `source("PRE_CLASS_SETUP.R")` to check the CSV and install packages, or `source("scripts/00_setup.R")` to set up without checking data.
4. Run `source("scripts/run_all.R")`. Alternatively, source scripts 01 through 06 sequentially.

The setup script installs these R packages if absent: `readr`, `dplyr`, `tidyr`, `tibble`, `stringr`, `ggplot2`, `tidytext`, `text2vec`, `glmnet`, `Matrix`, `zip`, `wordcloud`, `udpipe`.

**UDPipe:** On first execution, Script 04 downloads an English model into `models/`. Later executions reuse the first `.udpipe` file in that folder. Since the model is not packaged, exact POS/lemma outputs may vary if the upstream downloadable model changes. The uploaded run used `english-ewt-ud-2.5-191206.udpipe`.

## Outputs

- `outputs/tables/`: audits, text features, sentiment summaries, POS and burger counts, model metrics, and baseline comparisons.
- `outputs/figures/`: charts used during the lectures, including UDPipe and burger co-occurrence.
- `outputs/class_summary/`: a compact summary and selected plots/tables.
- `outputs/class_results.zip`: final course bundle.
- `outputs/private/`: local restaurant- or review-level intermediate outputs produced by Script 03. This folder is Git-ignored and should not be publicly uploaded.

## Reproducibility caveats

- Scripts contain fixed random seeds, but numeric results may change with package versions, downloaded models, operating system, or altered data files.
- POS analysis in Script 04 is an optional *methodological component*, even though `run_all.R` executes it by default. For a faster run, comment out its line in `run_all.R`.
- No lockfile with pinned package versions is provided; the recorded metrics in `results/` come from the user's supplied run.
- R was not executed when preparing this GitHub version. Changes were limited to replacing repeated UDPipe downloads and including linguistic outputs in Script 06; please rerun locally to verify.
