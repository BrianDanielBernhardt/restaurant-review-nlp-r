# ============================================================================
# LECTURE 1 | PART A: IMPORT AND EXPLORE CUSTOMER REVIEWS
# ============================================================================
# GOAL: Load real Yelp reviews, check the data, remove invalid/duplicate rows,
#       and create two simple exploratory graphs.
#
# BEFORE STARTING:Open Customer_Reviews_Course.Rproj in RStudio.
# ============================================================================

# ---------------------------------------------------------------------------
# STEP 1 | Load packages and course helper functions
# ---------------------------------------------------------------------------
# source() executes another R script. In the simplified course, 00_setup.R
# checks required packages and defines functions that save our figures.
source("scripts/00_setup.R")

library(dplyr)    # Filter, transform, and summarize tables
library(readr)    # Import and export CSV files
library(stringr)  # Clean and count text
library(ggplot2)  # Create graphs

# Creates output folders if they do not already exist.
ensure_output()

# CHECKPOINT: The working directory should be the MAIN project folder.
getwd()


# ---------------------------------------------------------------------------
# STEP 2 | Import the CSV file
# ---------------------------------------------------------------------------
# A relative path works on both Mac and Windows when the .Rproj is open.
DATA_FILE <- "data/raw/yelp_sentiment_master_dataset.csv"

raw_reviews <- read_csv(
  DATA_FILE,
  show_col_types = FALSE,
  locale = locale(encoding = "UTF-8")
)

# CHECKPOINT: Examine the original table before changing anything.
dim(raw_reviews)       # Number of rows and columns
names(raw_reviews)     # Original column names
glimpse(raw_reviews)   # Column types and sample values


# ---------------------------------------------------------------------------
# STEP 3 | Standardize column names
# ---------------------------------------------------------------------------
# Example: "SI No" becomes "si_no". This avoids spaces in variable names.
names(raw_reviews) <- tolower(
  gsub("_+", "_", gsub("[^a-zA-Z0-9]+", "_", names(raw_reviews)))
)

names(raw_reviews)  # CHECKPOINT: Are the column names simpler now?

# We need text, star rating, restaurant name and city to proceed.
raw_n <- nrow(raw_reviews)  # Remember the original row count for the audit.

# The CSV may contain a 'sentiment' field. We do NOT use it as an independent
# ground-truth label, because it may have been generated from star ratings.

# ---------------------------------------------------------------------------
# STEP 4 | Clean the main columns and remove invalid reviews
# ---------------------------------------------------------------------------
# str_squish(): remove extra spaces and line breaks from text.
# as.numeric(): make ratings numeric so that we can count stars.
# business_key: identify a restaurant using BOTH its city and its name.

# STEP 1: Start with the original dataset
valid_reviews <- raw_reviews


# STEP 2: Clean the text
# Remove unnecessary spaces and convert ratings to numbers
valid_reviews$text <- str_squish(valid_reviews$text)
valid_reviews$stars_review <- as.numeric(valid_reviews$stars_review)


# STEP 3: Remove reviews with missing information
# Keep only reviews with text and ratings between 1 and 5
valid_reviews <- valid_reviews %>%
  filter(
    !is.na(text),
    text != "",
    stars_review %in% 1:5
  )


# STEP 4: Clean restaurant names and cities
valid_reviews$name <- str_squish(valid_reviews$name)
valid_reviews$city <- str_squish(valid_reviews$city)

# Replace missing restaurant names or cities
valid_reviews$name[is.na(valid_reviews$name) | valid_reviews$name == ""] <- "Unknown business"
valid_reviews$city[is.na(valid_reviews$city) | valid_reviews$city == ""] <- "Unknown city"


# STEP 5: Create new variables
# Identify each restaurant using its city and name
valid_reviews$business_key <- paste(
  valid_reviews$city,
  valid_reviews$name,
  sep = " | "
)

# Lowercase text to identify duplicate reviews
valid_reviews$text_for_duplicates <- str_to_lower(valid_reviews$text)

# Count the number of words in each review
valid_reviews$n_words <- str_count(valid_reviews$text, "\\S+")


# STEP 6: Check the results
head(valid_reviews)
dim(valid_reviews)
summary(valid_reviews$stars_review)
summary(valid_reviews$n_words)

invalid_rows_removed <- raw_n - nrow(valid_reviews)




# ============================================================
# STEP 5: REMOVE DUPLICATE REVIEWS
# ============================================================

# Keep only one copy of the same review for the same restaurant.
reviews <- valid_reviews %>%
  distinct(business_key, text_for_duplicates, .keep_all = TRUE)

# Count how many duplicates were removed.
within_business_dups <- nrow(valid_reviews) - nrow(reviews)

# Give each review a unique ID.
reviews$review_id <- paste0("r", 1:nrow(reviews))

# Check the results.
cat("Duplicates removed:", within_business_dups, "\n")
cat("Reviews remaining:", nrow(reviews), "\n")

head(reviews)


# ============================================================
# STEP 6: CONVERT DATES
# ============================================================

# Convert text into dates (day-month-year).
reviews$review_date <- as.Date(reviews$date, format = "%d-%m-%y")

# Check the result.
head(reviews$review_date)


# ============================================================
# STEP 7: EXPLORE THE CLEANED DATASET
# ============================================================

# How many reviews do we have?
nrow(reviews)

# How many cities and restaurants?
n_distinct(reviews$city)
n_distinct(reviews$business_key)

# Count reviews by star rating.
star_distribution <- reviews %>%
  count(stars_review)

# Count reviews by city.
city_distribution <- reviews %>%
  count(city, sort = TRUE)

head(city_distribution, 10)

# Create a simple summary of the dataset.
audit <- data.frame(
  source_rows = nrow(raw_reviews),
  usable_reviews = nrow(reviews),
  missing_or_invalid_removed = nrow(raw_reviews) - nrow(valid_reviews),
  identical_within_business_removed = within_business_dups,
  unique_texts_global = n_distinct(reviews$text_for_duplicates),
  distinct_business_city_pairs = n_distinct(reviews$business_key),
  cities = n_distinct(reviews$city),
  ratings_1_2 = sum(reviews$stars_review %in% c(1, 2)),
  ratings_3 = sum(reviews$stars_review == 3),
  ratings_4_5 = sum(reviews$stars_review %in% c(4, 5)),
  missing_parsed_dates = sum(is.na(reviews$review_date))
)

print(audit)

# Save the tables.
write_csv(audit, "outputs/tables/01_data_audit.csv")
write_csv(star_distribution, "outputs/tables/01_star_distribution.csv")
write_csv(city_distribution, "outputs/tables/01_cities.csv")


# ============================================================
# STEP 8: VISUALIZE STAR RATINGS
# ============================================================

# geom_bar() counts the observations in each rating category.

p_ratings <- ggplot(reviews, aes(x = factor(stars_review))) +
  geom_bar(fill = "steelblue") +
  labs(
    title = "Star Rating Distribution",
    x = "Star rating",
    y = "Number of reviews"
  ) +
  theme_minimal()

# Show the graph.
print(p_ratings)

# Save the graph.
save_course_plot(p_ratings, "01_star_distribution.png", 9, 5)


# ============================================================
# STEP 9: VISUALIZE REVIEW LENGTH
# ============================================================

# n_words was created during the cleaning step.
# A histogram shows how many reviews are short or long.

p_length <- ggplot(reviews, aes(x = n_words)) +
  geom_histogram(bins = 40, fill = "steelblue") +
  labs(
    title = "Review Length Distribution",
    x = "Number of words",
    y = "Number of reviews"
  ) +
  theme_minimal()

print(p_length)

save_course_plot(p_length, "01_review_length.png", 9, 5)


# ============================================================
# END OF PART A
# ============================================================

cat("Part A completed! Next: text exploration.\n")
