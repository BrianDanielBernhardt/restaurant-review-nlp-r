
# ============================================================
# LECTURE 1 — PART C: SENTIMENT ANALYSIS
# ============================================================

# Run Scripts 01 and 02 before this script.

source("scripts/00_setup.R")

library(dplyr)
library(tidyr)
library(tidytext)
library(ggplot2)
library(readr)


# ============================================================
# STEP 1: LOAD THE SENTIMENT DICTIONARY
# ============================================================

# The Bing dictionary classifies English words as:
# "positive" or "negative".
#
# Examples:
# delicious = positive
# terrible  = negative

bing <- get_sentiments("bing")


# How many positive and negative words?
bing %>%
  count(sentiment)


# ============================================================
# STEP 2: FIND SENTIMENT WORDS IN OUR REVIEWS
# ============================================================

# Match the words from our reviews with the dictionary.
#
# We use 'tokens' from Script 02.
# We do NOT remove stopwords before sentiment analysis.

matched <- tokens %>%
  inner_join(bing, by = "word")

# Inspect the results.
head(matched, 20)

# Count all positive and negative word occurrences.
matched %>%
  count(sentiment)

# Give each positive word +1 and each negative word -1.
matched$val <- 1
matched$val[matched$sentiment == "negative"] <- -1

head(matched)


# ============================================================
# STEP 3: CALCULATE SENTIMENT FOR EACH REVIEW
# ============================================================

# Add the scores of the sentiment words.
#
# Example:
# "Great food but terrible service"
#
# great    = +1
# terrible = -1
#
# Total score = 0

raw_sentiment <- matched %>%
  group_by(review_id) %>%
  summarise(
    pos_matches = sum(val == 1),
    neg_matches = sum(val == -1),
    match_count = n(),
    raw_score = sum(val),
    .groups = "drop"
  )

raw_sentiment %>%
arrange(as.numeric(sub("^r", "", review_id)))


# ============================================================
# STEP 4: ADD SENTIMENT SCORES TO OUR DATASET
# ============================================================

# Merge the scores with the original reviews.

lex_results <- reviews %>%
  left_join(raw_sentiment, by = "review_id")

# Some reviews have no dictionary words.
# Replace their missing counts with zero.

lex_results <- lex_results %>%
  mutate(
    pos_matches = replace_na(pos_matches, 0),
    neg_matches = replace_na(neg_matches, 0),
    match_count = replace_na(match_count, 0),
    raw_score = replace_na(raw_score, 0)
  )

# Calculate normalized sentiment:
#
# normalized score = raw score / matched words
#
# Range: -1 to +1
# -1 = negative
# +1 = positive

lex_results$normalized_score <-
  lex_results$raw_score / lex_results$match_count

# Reviews without matched words have no normalized score.
lex_results$normalized_score[
  lex_results$match_count == 0
] <- NA

# Classify each review according to its score.
lex_results <- lex_results %>%
  mutate(
    dictionary_class = case_when(
      match_count == 0 ~ "no_dictionary_match",
      raw_score > 0 ~ "positive",
      raw_score < 0 ~ "negative",
      TRUE ~ "tie"
    )
  )

# Inspect the results.
head(lex_results)

# Count the review classifications.
lex_results %>%
  count(dictionary_class)


# ============================================================
# STEP 5: COMPARE SENTIMENT WITH STAR RATINGS
# ============================================================

# Do reviews with more stars also have higher sentiment?

summary_lex <- lex_results %>%
  group_by(stars_review) %>%
  summarise(
    n = n(),
    mean_raw = mean(raw_score),
    mean_normalized = mean(normalized_score, na.rm = TRUE),
    word_match_coverage = mean(match_count > 0),
    share_positive = mean(dictionary_class == "positive"),
    .groups = "drop"
  )

print(summary_lex)

write_csv(
  summary_lex,
  "outputs/tables/03_sentiment_by_stars.csv"
)


# VISUALIZATION: SENTIMENT BY STAR RATING

p_sent <- ggplot(
  lex_results,
  aes(x = factor(stars_review), y = normalized_score)
) +
  geom_boxplot(fill = "darkgreen") +
  labs(
    title = "Sentiment Scores by Star Rating",
    x = "Star Rating",
    y = "Normalized Sentiment Score"
  ) +
  theme_minimal()

print(p_sent)

save_course_plot(
  p_sent,
  "03_sentiment_vs_stars.png"
)


# VISUALIZATION: SENTIMENT CLASSIFICATIONS

p_class <- ggplot(
  lex_results,
  aes(x = dictionary_class)
) +
  geom_bar(fill = "steelblue") +
  labs(
    title = "Sentiment Classification of Reviews",
    x = "Sentiment Class",
    y = "Number of Reviews"
  ) +
  theme_minimal()

print(p_class)

save_course_plot(
  p_class,
  "03_lexicon_class_distribution.png"
)


# QUESTION:
# Do 1-star reviews always have negative sentiment scores?
# What happens when a review contains both positive and negative words?


# ============================================================
# STEP 6: MOST FREQUENT SENTIMENT WORDS
# ============================================================

# Which positive and negative words appear most often?

sentiment_words <- matched %>%
  count(word, sentiment, sort = TRUE)

head(sentiment_words, 20)

write_csv(
  sentiment_words,
  "outputs/tables/03_sentiment_word_counts.csv"
)

# Save review-level scores without review text.
write_csv(
  lex_results %>%
    select(
      review_id, stars_review, raw_score,
      normalized_score, match_count, dictionary_class
    ),
  "outputs/private/03_review_scores_PRIVATE.csv"
)


# ============================================================
# STEP 7: COMPARE RESTAURANTS
# ============================================================

# Calculate average sentiment by restaurant.
# Keep only restaurants with at least 10 reviews.

business_local <- lex_results %>%
  group_by(business_key) %>%
  summarise(
    n_reviews = n(),
    mean_rating = mean(stars_review),
    mean_dictionary_score = mean(normalized_score, na.rm = TRUE),
    coverage = mean(match_count > 0),
    .groups = "drop"
  ) %>%
  filter(n_reviews >= 10) %>%
  arrange(desc(n_reviews))

head(business_local, 10)

# Keep business-level results private.
write_csv(
  business_local,
  "outputs/private/03_business_summary_PRIVATE.csv"
)


# ============================================================
# STEP 8: NEGATION
# ============================================================

# A limitation of dictionaries:
#
# "The food was good"     -> positive
# "The food was not good" -> should be negative
#
# A simple lexicon ignores the word "not".

# Find the previous word in the same review.

positioned <- tokens %>%
  group_by(review_id) %>%
  mutate(previous_word = lag(word)) %>%
  ungroup()

# Match dictionary words again.

matched_neg <- positioned %>%
  inner_join(bing, by = "word")

# Assign positive and negative scores.
matched_neg$base <- 1
matched_neg$base[
  matched_neg$sentiment == "negative"
] <- -1

# Detect a negation immediately before a sentiment word.
matched_neg <- matched_neg %>%
  mutate(
    invert = previous_word %in% c("not", "never", "no")
  )

# Reverse the score when there is a negation.
matched_neg$adjusted <- matched_neg$base

matched_neg$adjusted[matched_neg$invert] <-
  -matched_neg$base[matched_neg$invert]

# Calculate adjusted sentiment per review.
neg_scores <- matched_neg %>%
  group_by(review_id) %>%
  summarise(
    negation_score = sum(adjusted),
    n_inverted = sum(invert),
    .groups = "drop"
  )

# Add the adjusted scores to our results.
neg_results <- lex_results %>%
  left_join(neg_scores, by = "review_id") %>%
  mutate(
    negation_score = replace_na(negation_score, 0),
    n_inverted = replace_na(n_inverted, 0)
  )

# How many reviews contained detected negations?
negation_audit <- data.frame(
  reviews_with_negation_inversion = sum(neg_results$n_inverted > 0),
  inverted_tokens = sum(neg_results$n_inverted)
)

print(negation_audit)

write_csv(
  negation_audit,
  "outputs/tables/03_negation_audit.csv"
)


# ============================================================
# STEP 9: A SIMPLE NEGATION EXAMPLE
# ============================================================

# Create four short examples to explain the problem.

negation_demo <- data.frame(
  review_id = paste0("example_", 1:4),
  example = c(
    "The food was good.",
    "The food was not good.",
    "The service was not bad.",
    "Great food but terrible service."
  )
)

# Tokenize and identify the previous word.
demo_tokens <- negation_demo %>%
  unnest_tokens(word, example) %>%
  group_by(review_id) %>%
  mutate(previous_word = lag(word)) %>%
  ungroup() %>%
  inner_join(bing, by = "word")

# Calculate original scores.
demo_tokens$base <- 1
demo_tokens$base[demo_tokens$sentiment == "negative"] <- -1

# Correct immediate negations.
demo_tokens$adjusted <- demo_tokens$base

negated <- demo_tokens$previous_word %in% c("not", "never", "no")

demo_tokens$adjusted[negated] <- -demo_tokens$base[negated]

# Compare scores.
demo_tokens <- demo_tokens %>%
  group_by(review_id) %>%
  summarise(
    raw_score = sum(base),
    simple_negation_score = sum(adjusted),
    .groups = "drop"
  )

print(demo_tokens)

write_csv(
  demo_tokens,
  "outputs/tables/03_authored_negation_demo.csv"
)


# ============================================================
# STEP 10: CORRELATION BETWEEN RATINGS AND SENTIMENT
# ============================================================

# Spearman correlation measures the association
# between star ratings and lexicon sentiment.
#
# A positive correlation means that higher ratings
# tend to be associated with higher sentiment scores.

spearman <- cor(
  lex_results$stars_review,
  lex_results$normalized_score,
  method = "spearman",
  use = "complete.obs"
)

print(spearman)

write_csv(
  data.frame(spearman_rating_vs_normalized_lexicon = spearman),
  "outputs/tables/03_spearman_summary.csv"
)


# ============================================================
# END OF PART C
# ============================================================

