# LECTURE 2 — PREDICT REVIEW RATINGS FROM CUSTOMER TEXT
#
# Goal: use restaurant reviews to predict whether customers gave
# a LOW rating (1–2 stars) or a HIGH rating (4–5 stars).
# We leave out 3-star reviews because they are between the two groups.
#
# IMPORTANT: The target is derived from STARS, not from a separate
# human assessment of the text. The CSV's 'sentiment' column is not used.
#
# Before running: open the .Rproj and run Script 01 to create 'reviews'.

source("scripts/00_setup.R")  # Packages, output folders and plotting helpers

library(dplyr)
library(tidyr)
library(tidytext)
library(ggplot2)
library(readr)
library(text2vec)
library(glmnet)

# Run Script 01 first: it creates the data frame needed below.
stopifnot(exists("reviews"), nrow(reviews) > 50)


# 1. PREPARE THE REVIEWS AND CREATE THE LABELS

set.seed(20261130)  # Same random selection every time we run the script
MAX_PER_CLASS <- 1200  # Limit each class to keep the classroom exercise fast

ml_reviews <- reviews %>%
  filter(stars_review %in% c(1, 2, 4, 5)) %>%
  distinct(text_for_duplicates, .keep_all = TRUE) %>%
  mutate(label = if_else(stars_review >= 4, "positive", "negative"))

# Removing identical texts BEFORE splitting prevents the same review
# from appearing in both the training and test datasets.

# Create two groups of reviews.
positive_pool <- ml_reviews %>% filter(label == "positive")
negative_pool <- ml_reviews %>% filter(label == "negative")

# The model needs enough examples from both classes.
if (min(nrow(positive_pool), nrow(negative_pool)) < 30) {
  stop("Not enough reviews in one of the rating groups.")
}

# Take up to 1,200 reviews from each group: a balanced dataset.
positive <- positive_pool %>%
  slice_sample(n = min(MAX_PER_CLASS, nrow(positive_pool)))
negative <- negative_pool %>%
  slice_sample(n = min(MAX_PER_CLASS, nrow(negative_pool)))

ml <- bind_rows(positive, negative)

# Check the number of reviews in each class.
count(ml, label)


# 2. CREATE TRAINING AND TEST DATASETS

# Training set: used to learn patterns from text.
# Test set: kept aside until the final model evaluation.
# We sample within each class so the 80/20 split stays balanced.

train <- ml %>%
  group_by(label) %>%
  slice_sample(prop = 0.80) %>%
  ungroup()

test <- ml %>%
  anti_join(train, by = "review_id")

# Tell R that our two classes have a fixed order.
train$label <- factor(train$label, levels = c("negative", "positive"))
test$label <- factor(test$label, levels = c("negative", "positive"))

# How many positive and negative reviews are in each set?
split_counts <- bind_rows(
  count(train, label) %>% mutate(split = "train"),
  count(test, label) %>% mutate(split = "test")
)
print(split_counts)
write_csv(split_counts, "outputs/tables/05_split_counts.csv")


# 3. RECALL TF-IDF FROM LECTURE 1

# Each review is a document. TF-IDF gives more weight to terms
# that are important within a document and less common overall.
# This small table is just for students to inspect; it uses TRAIN only.

train_tfidf_example <- train %>%
  select(review_id, text) %>%
  unnest_tokens(word, text) %>%
  count(review_id, word, name = "n") %>%
  bind_tf_idf(word, review_id, n) %>%
  arrange(desc(tf_idf))

head(train_tfidf_example, 8)
write_csv(head(train_tfidf_example, 50),
          "outputs/tables/05_example_tfidf_train_only.csv")


# 4. TURN REVIEWS INTO NUMERICAL FEATURES

# A machine-learning model cannot read raw sentences directly.
# We create a document-term matrix (DTM):
#   rows = reviews; columns = words/bigrams; values = term counts.
#
# A unigram is one word ("delicious").
# A bigram is two adjacent words ("great service").

# This short function tells text2vec how to read a dataset's texts.
make_iterator <- function(data) {
  itoken(
    data$text,
    preprocessor = tolower,
    tokenizer = word_tokenizer,
    ids = data$review_id,
    progressbar = FALSE
  )
}

# Learn the vocabulary from TRAIN ONLY (no test information).
vocab <- create_vocabulary(make_iterator(train), ngram = c(1L, 2L))

# Remove very rare terms (fewer than 3 occurrences) and terms
# appearing in more than 85% of training documents.
vocab <- prune_vocabulary(
  vocab,
  term_count_min = 3,
  doc_proportion_max = 0.85
)

# Inspect the vocabulary and its size.
head(vocab)
nrow(vocab)

# Use the SAME training vocabulary for train and test reviews.
vectorizer <- vocab_vectorizer(vocab)
x_train_counts <- create_dtm(make_iterator(train), vectorizer)
x_test_counts <- create_dtm(make_iterator(test), vectorizer)

# The matrices must have the same number of columns (features).
dim(x_train_counts)
dim(x_test_counts)


# 5. APPLY TF-IDF TO THE MATRICES

# Learn IDF weights on TRAIN, then reuse those weights on TEST.
# Doing this separately on the test set would introduce leakage.

tfidf_transformer <- TfIdf$new()
x_train <- tfidf_transformer$fit_transform(x_train_counts)
x_test <- tfidf_transformer$transform(x_test_counts)

# Convert the labels to numbers: negative = 0; positive = 1.
y_train <- as.integer(train$label == "positive")
y_test <- as.integer(test$label == "positive")


# 6. TRAIN A LOGISTIC REGRESSION MODEL

# Logistic regression estimates the probability of a positive rating.
# alpha = 1 means LASSO (L1 regularization): unhelpful coefficients
# can be shrunk to zero.
# cv.glmnet uses 5-fold cross-validation ON TRAIN to choose lambda,
# the amount of regularization.

set.seed(20261130)
model <- cv.glmnet(
  x_train,
  y_train,
  family = "binomial",
  alpha = 1,
  nfolds = 5,
  type.measure = "class"
)

# Chosen regularization parameter.
model$lambda.min

# Estimate the probability of a positive rating for each TEST review.
p <- as.numeric(predict(
  model, newx = x_test,
  s = "lambda.min", type = "response"
))

# Convert probabilities to labels using a 0.50 threshold.
pred <- factor(
  ifelse(p >= 0.5, "positive", "negative"),
  levels = c("negative", "positive")
)


# 7. EVALUATE THE MODEL ON TEST DATA

# Confusion matrix: compare actual ratings with predictions.
conf <- table(Actual = test$label, Predicted = pred)
print(conf)

# TP = correctly predicted positive; TN = correctly predicted negative.
# FP = predicted positive but actually negative.
# FN = predicted negative but actually positive.
TP <- sum(pred == "positive" & test$label == "positive")
TN <- sum(pred == "negative" & test$label == "negative")
FP <- sum(pred == "positive" & test$label == "negative")
FN <- sum(pred == "negative" & test$label == "positive")

# Precision: among predicted positives, how many were truly positive?
# Recall: among actual positives, how many did the model find?
precision <- safe_ratio(TP, TP + FP)
recall <- safe_ratio(TP, TP + FN)

# ROC AUC measures how well the model ranks positive above negative
# reviews across all possible classification thresholds.
# The ranking formula below avoids installing an extra R package.
auc_rank <- function(prob, truth) {
  n_pos <- sum(truth == 1)
  n_neg <- sum(truth == 0)
  positive_ranks <- sum(rank(prob, ties.method = "average")[truth == 1])
  (positive_ranks - n_pos * (n_pos + 1) / 2) / (n_pos * n_neg)
}

metrics <- tibble::tibble(
  n_train = nrow(train),
  n_test = nrow(test),
  n_features = ncol(x_train),
  accuracy = mean(pred == test$label),
  balanced_accuracy = mean(c(
    safe_ratio(TP, TP + FN), safe_ratio(TN, TN + FP)
  )),
  precision = precision,
  recall = recall,
  f1 = safe_ratio(2 * precision * recall, precision + recall),
  roc_auc = auc_rank(p, y_test),
  brier = mean((p - y_test)^2),
  lambda_min = model$lambda.min
)

print(metrics, width = Inf)
write_csv(metrics, "outputs/tables/05_model_metrics.csv")
write_csv(
  as.data.frame.matrix(conf) %>% tibble::rownames_to_column("true_class"),
  "outputs/tables/05_confusion_matrix.csv"
)

# Discussion: Accuracy uses a 0.50 threshold; ROC AUC uses the entire
# ranking of predicted probabilities. The Brier score evaluates how
# close the predicted probabilities are to the actual 0/1 outcomes.


# 8. COMPARE WITH THE BING DICTIONARY FROM LECTURE 1

# The lexicon is our simple baseline: +1 for positive words and
# -1 for negative words. Both methods are assessed on the SAME test set.

bing <- get_sentiments("bing")

test_bing <- test %>%
  select(review_id, text) %>%
  unnest_tokens(word, text) %>%
  inner_join(bing, by = "word") %>%
  mutate(value = if_else(sentiment == "positive", 1L, -1L)) %>%
  group_by(review_id) %>%
  summarise(score = sum(value), .groups = "drop")

comparison <- test %>%
  select(review_id, label, stars_review, text) %>%
  mutate(
    p_positive = p,
    predicted = as.character(pred),
    correct = predicted == as.character(label)
  ) %>%
  left_join(test_bing, by = "review_id") %>%
  mutate(
    score = replace_na(score, 0L),
    bing_pred = case_when(
      score > 0 ~ "positive",
      score < 0 ~ "negative",
      TRUE ~ "abstain"  # No matches or equal positive/negative scores
    )
  )

# To compare all test reviews, count lexicon abstentions as errors.
baseline <- tibble::tibble(
  method = c("Bing lexicon (abstentions = errors)",
             "TF-IDF + L1 logistic regression"),
  accuracy = c(mean(comparison$bing_pred == as.character(comparison$label)),
               metrics$accuracy),
  abstention_rate = c(mean(comparison$bing_pred == "abstain"), 0),
  n = nrow(test)
)

print(baseline)
write_csv(baseline, "outputs/tables/05_baseline_comparison.csv")

# Discussion: The Bing baseline sometimes abstains. Its accuracy among
# ONLY classified reviews will therefore be different from the figure above.


# 9. INSPECT THE INCORRECT PREDICTIONS

# These are useful examples to discuss in class: jokes, mixed opinions,
# negations and unusual vocabulary can cause classification errors.
errors <- comparison %>%
  filter(!correct) %>%
  mutate(confidence = pmax(p_positive, 1 - p_positive)) %>%
  arrange(desc(confidence))

# View(errors) opens the reviews in RStudio. No automatic text export.
head(errors %>% select(stars_review, label, predicted, p_positive), 10)

# Save only numeric/model information for later analysis.
write_csv(
  comparison %>% select(review_id, label, stars_review,
                        p_positive, predicted, correct, bing_pred),
  "outputs/tables/05_predictions.csv"
)
write_csv(
  errors %>% select(review_id, stars_review, label,
                    predicted, p_positive, confidence),
  "outputs/tables/05_error_summary.csv"
)


# 10. WHICH TERMS DOES THE MODEL USE?

# The fitted coefficients describe associations with the predicted class.
# Positive coefficients push predictions toward positive ratings;
# negative coefficients push them toward negative ratings.
# They do NOT establish a causal relationship.

coefficient_matrix <- as.matrix(coef(model, s = "lambda.min"))
coeff <- tibble::tibble(
  term = rownames(coefficient_matrix),
  coefficient = as.numeric(coefficient_matrix[, 1])
) %>%
  filter(term != "(Intercept)", coefficient != 0)

write_csv(coeff, "outputs/tables/05_nonzero_coefficients.csv")

# Show the ten strongest positive and ten strongest negative features.
top_coef <- bind_rows(
  coeff %>% slice_max(coefficient, n = 10, with_ties = FALSE),
  coeff %>% slice_min(coefficient, n = 10, with_ties = FALSE)
) %>%
  distinct(term, .keep_all = TRUE)

p_coef <- ggplot(top_coef,
                 aes(x = reorder(term, coefficient), y = coefficient,
                     fill = coefficient > 0)) +
  geom_col(show.legend = FALSE) +
  coord_flip() +
  scale_fill_manual(values = c("TRUE" = "darkgreen", "FALSE" = "darkred")) +
  labs(title = "Most influential fitted terms",
       subtitle = "Statistical associations, not causal effects",
       x = NULL, y = "Logistic regression coefficient") +
  course_theme(11)

print(p_coef)
save_course_plot(p_coef, "05_model_coefficients.png", 11, 7)


# 11. VISUALIZE THE PREDICTED PROBABILITIES

# Ideally, negative reviews have small predicted P(positive), while
# positive reviews have large predicted P(positive).

p_probs <- ggplot(comparison, aes(x = p_positive, fill = label)) +
  geom_histogram(bins = 24, alpha = 0.62, position = "identity") +
  scale_fill_manual(values = c(negative = "darkred", positive = "darkgreen")) +
  labs(title = "Predicted probabilities on test reviews",
       subtitle = "1–2 stars vs 4–5 stars; 3-star reviews excluded",
       x = "Predicted probability of a positive rating",
       y = "Number of reviews", fill = "Actual rating class") +
  course_theme()

print(p_probs)
save_course_plot(p_probs, "05_probability_histogram.png")


# 12. CHECK PROBABILITY CALIBRATION (ADVANCED)

# We arrange predictions into ten groups, from lower to higher
# probability. Within each group, compare:
#   mean_pred = mean model probability
#   observed_share = actual proportion of positive reviews.
# Points near the diagonal indicate better calibration.

calibration <- comparison %>%
  mutate(actual_positive = as.integer(label == "positive"),
         bin = ntile(p_positive, 10)) %>%
  group_by(bin) %>%
  summarise(mean_pred = mean(p_positive),
            observed_share = mean(actual_positive),
            n = n(), .groups = "drop")

print(calibration)
write_csv(calibration, "outputs/tables/05_calibration.csv")

p_cal <- ggplot(calibration, aes(x = mean_pred, y = observed_share)) +
  geom_abline(intercept = 0, slope = 1, linetype = 2, color = "grey") +
  geom_line(color = "blue") +
  geom_point(aes(size = n), color = "lightblue") +
  coord_equal(xlim = c(0, 1), ylim = c(0, 1)) +
  labs(title = "Probability calibration (illustrative)",
       x = "Average predicted probability",
       y = "Observed positive share", size = "Reviews") +
  course_theme()

print(p_cal)
save_course_plot(p_cal, "05_calibration.png", 8, 6)


