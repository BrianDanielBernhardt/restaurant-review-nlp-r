# LECTURE 2 — FINAL STEP: SUMMARIZE OUR RESULTS
# Run this AFTER Scripts 01–05 (including the UDPipe analysis).
# We will create one short report and a ZIP with our main figures and tables.

source("scripts/00_setup.R")
library(readr)

# 1. Read the results that our previous scripts saved.
audit <- read_csv("outputs/tables/01_data_audit.csv", show_col_types = FALSE)
ratings <- read_csv("outputs/tables/01_star_distribution.csv", show_col_types = FALSE)
words <- read_csv("outputs/tables/02_word_frequencies.csv", show_col_types = FALSE)
bigrams <- read_csv("outputs/tables/02_filtered_bigrams.csv", show_col_types = FALSE)
sentiment <- read_csv("outputs/tables/03_spearman_summary.csv", show_col_types = FALSE)
metrics <- read_csv("outputs/tables/05_model_metrics.csv", show_col_types = FALSE)
baseline <- read_csv("outputs/tables/05_baseline_comparison.csv", show_col_types = FALSE)

# 2. Calculate a few numbers to report.
mean_stars <- sum(ratings$stars_review * ratings$n) / sum(ratings$n)
positive_share <- sum(ratings$n[ratings$stars_review >= 4]) / sum(ratings$n)

# Summarize the optional linguistic analysis when its files exist.
pos_lines <- "UDPipe analysis not run."
pos_file <- "outputs/tables/04_lemma_frequency_by_pos.csv"
if (file.exists(pos_file)) {
  pos_terms <- read_csv(pos_file, show_col_types = FALSE)
  pos_lines <- c(
    paste("Top nouns:", paste(head(pos_terms$lemma[pos_terms$upos == "NOUN"], 3), collapse = ", ")),
    paste("Top adjectives:", paste(head(pos_terms$lemma[pos_terms$upos == "ADJ"], 3), collapse = ", ")),
    paste("Top verbs:", paste(head(pos_terms$lemma[pos_terms$upos == "VERB"], 3), collapse = ", "))
  )
}

burger_lines <- "Burger co-occurrence analysis not run."
burger_file <- "outputs/tables/04_burger_adjectives.csv"
if (file.exists(burger_file)) {
  burger_terms <- read_csv(burger_file, show_col_types = FALSE)
  burger_lines <- paste("Adjectives in burger sentences:",
                        paste(head(burger_terms$lemma, 5), collapse = ", "))
}

# 3. Build a readable summary of our analysis.
report <- c(
  "CUSTOMER REVIEW ANALYTICS — CLASS RESULTS",
  "",
  "DATASET",
  paste("Reviews analyzed:", audit$usable_reviews[1]),
  paste("Cities:", audit$cities[1]),
  sprintf("Average star rating: %.2f out of 5", mean_stars),
  sprintf("Reviews with 4 or 5 stars: %.1f%%", 100 * positive_share),
  "",
  "TEXT EXPLORATION",
  paste("Most frequent words:", paste(head(words$word, 5), collapse = ", ")),
  paste("Frequent filtered bigrams:", paste(head(bigrams$bigram, 5), collapse = ", ")),
  "",
  "LEXICON SENTIMENT",
  sprintf("Spearman correlation with star ratings: %.3f",
          sentiment$spearman_rating_vs_normalized_lexicon[1]),
  "",
  "LINGUISTIC ANNOTATION (UDPIPE)",
  pos_lines,
  burger_lines,
  "Note: burger adjective counts are sentence-level co-occurrences, not necessarily noun modifiers.",
  "",
  "MACHINE LEARNING (HELD-OUT TEST SET)",
  paste("Test reviews:", metrics$n_test[1]),
  sprintf("Accuracy: %.1f%%", 100 * metrics$accuracy[1]),
  sprintf("F1 score: %.3f", metrics$f1[1]),
  sprintf("ROC AUC: %.3f", metrics$roc_auc[1]),
  "",
  "METHOD COMPARISON",
  paste0(baseline$method, ": ", sprintf("%.1f%%", 100 * baseline$accuracy)),
  "",
  "QUESTIONS FOR DISCUSSION",
  "1. What topics appear most often in restaurant reviews?",
  "2. Why are filtered bigrams more informative than raw bigrams?",
  "3. Why can a low-rated review contain positive words?",
  "4. Did the supervised model improve on the dictionary baseline?",
  "5. What are the main limitations of this analysis?",
  "",
  "NOTE: The classification target comes from star ratings (1-2 vs 4-5).",
  "Three-star reviews are excluded from model evaluation."
)

# 4. Save the report and inspect it in RStudio.
dir.create("outputs/class_summary", showWarnings = FALSE)
writeLines(report, "outputs/class_summary/CLASS_SUMMARY.txt")
cat(paste(report, collapse = "\n"), "\n")

# 5. Gather only the most useful tables and figures for submission.
dir.create("outputs/class_summary/tables", showWarnings = FALSE)
dir.create("outputs/class_summary/figures", showWarnings = FALSE)

tables <- c(
  "01_data_audit.csv", "01_star_distribution.csv",
  "02_filtered_bigrams.csv", "02_tfidf_top_city_terms.csv",
  "03_sentiment_by_stars.csv", "04_pos_counts.csv",
  "04_lemma_frequency_by_pos.csv", "04_burger_adjectives.csv",
  "04_burger_direct_adjectives.csv", "05_model_metrics.csv",
  "05_confusion_matrix.csv", "05_baseline_comparison.csv"
)

figures <- c(
  "01_star_distribution.png", "02_top_words.png",
  "02_bigrams_raw.png", "02_bigrams_filtered.png",
  "02_tfidf_by_city.png", "03_sentiment_vs_stars.png",
  "04_pos_lemmas.png", "04_burger_adjectives.png",
  "05_model_coefficients.png", "05_probability_histogram.png"
)

# Copy only files that exist (Script 04 may have been skipped).
tables <- tables[file.exists(file.path("outputs/tables", tables))]
figures <- figures[file.exists(file.path("outputs/figures", figures))]

file.copy(file.path("outputs/tables", tables),
          "outputs/class_summary/tables", overwrite = TRUE)
file.copy(file.path("outputs/figures", figures),
          "outputs/class_summary/figures", overwrite = TRUE)

# 6. Create one ZIP file containing the final results.
zip::zip(
  zipfile = file.path(getwd(), "outputs", "class_results.zip"),
  files = list.files("outputs/class_summary", recursive = TRUE),
  root = file.path(getwd(), "outputs", "class_summary"),
  mode = "mirror"
)

