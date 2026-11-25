
# ============================================================
# LECTURE 1 — PART D: LEMMATIZATION AND POS TAGGING
# ============================================================

# Run Script 01 first, so the object 'reviews' exists.

library(dplyr)
library(ggplot2)
library(tidytext)
library(readr)
library(udpipe)


# ============================================================
# STEP 1: LOAD THE ENGLISH LANGUAGE MODEL
# ============================================================

# UDPipe identifies the grammatical role of each word.
#
# Examples:
# "delicious" = ADJ (adjective)
# "food"      = NOUN (noun)
# "eating"    = VERB (verb)
#
# It also performs lemmatization:
# "eating", "eats", "ate" -> "eat"


# The R package is installed by scripts/00_setup.R.
# The separate English language model is downloaded only if missing.
# A model already saved in models/ will be reused on later runs.
dir.create("models", showWarnings = FALSE)

model_files <- list.files(
  "models",
  pattern = "\\.udpipe$",
  full.names = TRUE
)

if (length(model_files) == 0) {
  message("Downloading the English UDPipe model (first run only)...")
  downloaded <- udpipe_download_model(language = "english", model_dir = "models")
  model_files <- downloaded$file_model
}

# Load the saved language model.
model <- udpipe_load_model(model_files[1])


# ============================================================
# STEP 2: SELECT A SAMPLE OF REVIEWS
# ============================================================

# We use only 250 reviews to keep the exercise fast.
# set.seed() ensures that the sample is reproducible.

set.seed(123)

pos_sample <- reviews %>%
  slice_sample(n = min(250, nrow(reviews)))

# Inspect the sample.
head(pos_sample)
nrow(pos_sample)


# ============================================================
# STEP 3: ANNOTATE THE REVIEWS
# ============================================================

# UDPipe identifies:
# - Token: the original word
# - Lemma: the dictionary form
# - UPOS: the grammatical category

annotated <- udpipe_annotate(
  model,
  x = pos_sample$text,
  doc_id = pos_sample$review_id
)

# Convert the result into a data frame.
annotated <- as.data.frame(annotated)

# Inspect the linguistic annotations.
head(annotated, 20)

# Look at specific columns.
head(annotated[, c("token", "lemma", "upos")], 20)


# ============================================================
# STEP 4: COUNT GRAMMATICAL CATEGORIES
# ============================================================

# How many nouns, verbs, adjectives, etc.?

pos_counts <- annotated %>%
  count(upos, sort = TRUE)

print(pos_counts)

write_csv(pos_counts, "outputs/tables/04_pos_counts.csv")


# ============================================================
# STEP 5: ANALYZE NOUNS, ADJECTIVES AND VERBS
# ============================================================

# NOUN = noun       (food, service, restaurant)
# ADJ  = adjective  (good, expensive, delicious)
# VERB = verb       (eat, order, recommend)

# Keep only nouns, adjectives and verbs.
content_pos <- annotated %>%
  filter(upos %in% c("NOUN", "ADJ", "VERB")) %>%
  filter(!is.na(lemma)) %>%
  mutate(lemma = tolower(lemma)) %>%
  count(upos, lemma, sort = TRUE)

# Inspect the results.
head(content_pos, 20)

# Save the word frequencies.
write_csv(
  content_pos,
  "outputs/tables/04_lemma_frequency_by_pos.csv"
)


# ============================================================
# STEP 6: SELECT THE MOST FREQUENT LEMMAS
# ============================================================

# Select the 12 most frequent lemmas in each category.

top_by_pos <- content_pos %>%
  group_by(upos) %>%
  slice_max(n, n = 12, with_ties = FALSE) %>%
  ungroup()

print(top_by_pos)


# ============================================================
# STEP 7: VISUALIZE THE RESULTS
# ============================================================

# Create one graph with three panels:
# adjectives, nouns and verbs.

# reorder_within() orders words within each grammatical group.
top_by_pos <- top_by_pos %>%
  mutate(lemma_plot = reorder_within(lemma, n, upos))

p_pos <- ggplot(
  top_by_pos,
  aes(x = n, y = lemma_plot, fill = upos)
) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~upos, scales = "free_y") +
  scale_y_reordered() +
  labs(
    title = "Most Frequent Nouns, Adjectives and Verbs",
    subtitle = "UDPipe Analysis of 250 Restaurant Reviews",
    x = "Word Frequency",
    y = "Lemma"
  ) +
  theme_minimal()

# Display the graph.
print(p_pos)

# Save the graph.
ggsave(
  "outputs/figures/04_pos_lemmas.png",
  plot = p_pos,
  width = 12,
  height = 7,
  bg = "white"
)


# STEP 8: WHAT DO CUSTOMERS SAY ABOUT BURGERS?

# Find reviews mentioning "burger" or "burgers".
burger_reviews <- reviews %>%
  filter(stringr::str_detect(
    stringr::str_to_lower(text),
    "\\bburgers?\\b"
  ))

# How many reviews mention burgers?
nrow(burger_reviews)

# Apply UDPipe to these reviews.
burger_data <- udpipe_annotate(
  model,
  x = burger_reviews$text,
  doc_id = burger_reviews$review_id
)

burger_data <- as.data.frame(burger_data)

head(burger_data)


# Identify sentences containing the noun "burger".
burger_sentences <- burger_data %>%
  filter(upos == "NOUN", tolower(lemma) == "burger") %>%
  distinct(doc_id, paragraph_id, sentence_id)

# Keep words from those sentences.
burger_words <- burger_data %>%
  semi_join(
    burger_sentences,
    by = c("doc_id", "paragraph_id", "sentence_id")
  )

# Select adjectives and count their occurrences.
burger_adjectives <- burger_words %>%
  filter(upos == "ADJ") %>%
  filter(!is.na(lemma)) %>%
  mutate(lemma = tolower(lemma)) %>%
  count(lemma, sort = TRUE)

# See the most frequent adjectives.
head(burger_adjectives, 20)


# Select the 15 most frequent adjectives.
top_burger_adj <- head(burger_adjectives, 15)

# Create a bar chart.
p_burger <- ggplot(
  top_burger_adj,
  aes(x = reorder(lemma, n), y = n)
) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Adjectives in Sentences Mentioning Burgers",
    x = "Adjective",
    y = "Frequency"
  ) +
  theme_minimal()

print(p_burger)

# Save the figure.
ggsave(
  "outputs/figures/04_burger_adjectives.png",
  plot = p_burger,
  width = 9,
  height = 6,
  bg = "white"
)

write_csv(
  burger_adjectives,
  "outputs/tables/04_burger_adjectives.csv"
)


# Find "burger" nouns and their token IDs.
burger_nouns <- burger_data %>%
  filter(upos == "NOUN", tolower(lemma) == "burger") %>%
  select(
    doc_id, paragraph_id, sentence_id,
    burger_id = token_id
  )

# Find adjectives directly modifying those nouns.
burger_modifiers <- burger_data %>%
  filter(upos == "ADJ", dep_rel == "amod") %>%
  inner_join(
    burger_nouns,
    by = c("doc_id", "paragraph_id", "sentence_id",
           "head_token_id" = "burger_id")
  )

# Count the adjectives directly attached to "burger".
burger_direct_adj <- burger_modifiers %>%
  mutate(lemma = tolower(lemma)) %>%
  count(lemma, sort = TRUE)

head(burger_direct_adj, 20)

# Save direct adjective–noun dependencies separately.
write_csv(
  burger_direct_adj,
  "outputs/tables/04_burger_direct_adjectives.csv"
)


# ============================================================
# END OF PART D
# ============================================================

cat("UDPipe analysis completed!\n")
