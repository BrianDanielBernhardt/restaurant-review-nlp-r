
# ============================================================
# LECTURE 1 — PART B: TEXT ANALYSIS
# ============================================================

# Run Script 01 first, so the object 'reviews' exists.

source("scripts/00_setup.R")

library(dplyr)
library(tidyr)
library(tidytext)
library(stringr)
library(ggplot2)
library(readr)


# ============================================================
# STEP 1: TOKENIZATION
# ============================================================

# Tokenization means splitting sentences into individual words.
# unnest_tokens() also converts words to lowercase.

tokens <- reviews %>%
  select(review_id, city, business_key, text) %>%
  unnest_tokens(word, text)

# Look at the results.
head(tokens, 20)

# Total number of words in the dataset.
nrow(tokens)


# ============================================================
# STEP 2: REMOVE STOPWORDS
# ============================================================

# Stopwords are common words such as "the", "is", "and".
# They are often removed when studying word frequencies.

stop_words <- tidytext::stop_words


# Keep words that are NOT in the stopword dictionary.
content_words <- tokens %>%
  anti_join(stop_words, by = "word") %>%
  filter(str_length(word) >= 2) %>%
  filter(!str_detect(word, "^[0-9]+$"))

# Compare the number of tokens before and after cleaning.
nrow(tokens)
nrow(content_words)

head(content_words)


# ============================================================
# STEP 3: WORD FREQUENCY
# ============================================================

# Count how many times each word appears.

word_frequency <- content_words %>%
  count(word, sort = TRUE)

# Display the 20 most frequent words.
head(word_frequency, 20)

# Save the results.
write_csv(word_frequency, "outputs/tables/02_word_frequencies.csv")


# VISUALIZATION: MOST FREQUENT WORDS

p_words <- word_frequency %>%
  slice_head(n = 20) %>%
  ggplot(aes(x = reorder(word, n), y = n)) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Most Frequent Words",
    x = "Word",
    y = "Frequency"
  ) +
  theme_minimal()

print(p_words)

save_course_plot(p_words, "02_top_words.png")


# QUESTION:
# Is a frequent word necessarily a positive or negative word?


# ============================================================
# STEP 4: BIGRAMS
# ============================================================

# A bigram is a sequence of two consecutive words.
# Examples: "great food", "bad service", "very expensive".

# Start with the ORIGINAL reviews, not the cleaned word list.
bigram_rows <- reviews %>%
  select(review_id, text) %>%
  unnest_tokens(bigram, text, token = "ngrams", n = 2)

head(bigram_rows)

# Count the most frequent bigrams.
raw_bigrams <- bigram_rows %>%
  count(bigram, sort = TRUE)

head(raw_bigrams, 20)


# VISUALIZATION: RAW BIGRAMS

p_bigrams_raw <- raw_bigrams %>%
  slice_head(n = 15) %>%
  ggplot(aes(x = reorder(bigram, n), y = n)) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Most Frequent Bigrams (Before Cleaning)",
    x = "Bigram",
    y = "Frequency"
  ) +
  theme_minimal()

print(p_bigrams_raw)

save_course_plot(p_bigrams_raw, "02_bigrams_raw.png")


# ============================================================
# STEP 5: FILTER BIGRAMS
# ============================================================

# Some bigrams are not informative: "and the", "it was".
# We remove common words from the two-word combinations.
#
# IMPORTANT: Keep words such as "not" and "very".
# They can change the meaning: "not good", "very bad".

bigram_stopwords <- setdiff(
  stop_words$word,
  c("not", "no", "never", "very", "too", "really")
)

# Split the bigram into two separate words.
bigram_rows <- bigram_rows %>%
  separate(bigram, into = c("word1", "word2"),
           sep = " ", remove = FALSE)

# Remove incomplete bigrams and unwanted words.
informative_bigrams <- bigram_rows %>%
  filter(!is.na(word1), !is.na(word2)) %>%
  filter(!word1 %in% bigram_stopwords) %>%
  filter(!word2 %in% bigram_stopwords) %>%
  count(bigram, sort = TRUE)

head(informative_bigrams, 20)

# Save both versions.
write_csv(raw_bigrams, "outputs/tables/02_raw_bigrams.csv")
write_csv(informative_bigrams, "outputs/tables/02_filtered_bigrams.csv")


# VISUALIZATION: FILTERED BIGRAMS

p_bigrams <- informative_bigrams %>%
  slice_head(n = 15) %>%
  ggplot(aes(x = reorder(bigram, n), y = n)) +
  geom_col(fill = "red") +
  coord_flip() +
  labs(
    title = "Most Frequent Bigrams (After Cleaning)",
    x = "Bigram",
    y = "Frequency"
  ) +
  theme_minimal()

print(p_bigrams)

save_course_plot(p_bigrams, "02_bigrams_filtered.png")


# QUESTION:
# Compare the raw bigrams with the filtered bigrams.
# Which expressions are more useful for understanding reviews?


# ============================================================
# STEP 6: TF-IDF
# ============================================================

# TF-IDF measures the importance of a word in a document.
#
# TF = Term Frequency
# IDF = Inverse Document Frequency
#
# Here, each individual review is a document.

# Count how often each word appears in each review.
word_counts <- content_words %>%
  count(review_id, word, name = "n")

head(word_counts)

# Calculate TF-IDF for each word in each review.
review_tf_idf <- word_counts %>%
  bind_tf_idf(word, review_id, n)

# Display the words with the highest TF-IDF values.
review_tf_idf %>%
  arrange(desc(tf_idf)) %>%
  head(5)


# ============================================================
# STEP 7: COMPARE TF-IDF ACROSS CITIES
# ============================================================

# Calculate the number of reviews per city.
city_counts <- reviews %>%
  count(city, name = "n_reviews")

# Add the city to each TF-IDF observation.
city_tfidf <- review_tf_idf %>%
  left_join(
    reviews %>% select(review_id, city),
    by = "review_id"
  )

# Calculate average TF-IDF for words in each city.
# Divide by ALL reviews in the city, not just those using the word.
city_tfidf <- city_tfidf %>%
  group_by(city, word) %>%
  summarise(
    sum_tfidf = sum(tf_idf),
    n_reviews_using_word = n(),
    .groups = "drop"
  ) %>%
  left_join(city_counts, by = "city") %>%
  mutate(mean_tfidf = sum_tfidf / n_reviews)

# Select the four cities with the most reviews.
top_cities <- city_counts %>%
  arrange(desc(n_reviews)) %>%
  head(4)

# Select the eight highest-scoring words in each city.
city_plot_data <- city_tfidf %>%
  semi_join(top_cities, by = "city") %>%
  group_by(city) %>%
  slice_max(mean_tfidf, n = 8, with_ties = FALSE) %>%
  ungroup()

# Prepare the word order for the faceted graph.
city_plot_data <- city_plot_data %>%
  mutate(
    word_plot = reorder_within(word, mean_tfidf, city)
  )

# VISUALIZATION: TF-IDF BY CITY

p_tfidf <- ggplot(
  city_plot_data,
  aes(x = mean_tfidf, y = word_plot)
) +
  geom_col(fill = "steelblue") +
  facet_wrap(~city, scales = "free_y") +
  scale_y_reordered() +
  labs(
    title = "High Mean TF-IDF Words by City",
    x = "Mean Review-Level TF-IDF",
    y = "Word"
  ) +
  theme_minimal()

print(p_tfidf)

save_course_plot(p_tfidf, "02_tfidf_by_city.png", 12, 7)

# Save the tables.
write_csv(city_tfidf, "outputs/tables/02_tfidf_city.csv")

write_csv(
  city_plot_data %>%
    select(city, word, mean_tfidf, n_reviews),
  "outputs/tables/02_tfidf_top_city_terms.csv"
)


# QUESTION:
# Do frequent words always have high TF-IDF values?
# Does a high TF-IDF value mean that a word is positive?


# ============================================================
# STEP 8: WORDCLOUD (OPTIONAL)
# ============================================================

# Install the package once, before the lecture:
# install.packages("wordcloud")

# Select the 100 most frequent words.
top_words <- head(word_frequency, 100)

# Create and display the wordcloud in RStudio.
set.seed(123)

wordcloud::wordcloud(
  words = top_words$word,
  freq = top_words$n,
  max.words = 100,
  random.order = FALSE
)

# Save the wordcloud as a PNG file.
png("outputs/figures/02_wordcloud.png",
    width = 1500, height = 900, res = 150)

set.seed(123)

wordcloud::wordcloud(
  words = top_words$word,
  freq = top_words$n,
  max.words = 100,
  random.order = FALSE
)

dev.off()


# ============================================================
# END OF PART B
# ============================================================

