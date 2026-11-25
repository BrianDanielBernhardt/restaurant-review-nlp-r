# PRE-CLASS CHECK
# Open Customer_Reviews_Course.Rproj first.

# 1. Check the working directory
if (!file.exists("scripts/01_import_audit.R")) {
  stop("Please open Customer_Reviews_Course.Rproj first.")
}

cat("Working directory:", getwd(), "\n")

# 2. Check the dataset
if (!file.exists("data/raw/yelp_sentiment_master_dataset.csv")) {
  stop("Dataset missing! Put the CSV in data/raw/")
}

cat("Dataset found!\n")

# 3. Install or check required packages
source("scripts/00_setup.R")

cat("Setup complete. Ready for the lecture!\n")