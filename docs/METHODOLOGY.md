# Methodology and interpretation

## Source and cleaning

The input is an English-language restaurant-review extract deposited on [Zenodo](https://zenodo.org/records/18723813). `01_import_audit.R` standardizes names and text, checks star ratings, removes invalid records and duplicates within restaurant–city groups, and creates a synthetic `review_id`. The delivered run contains 14,350 usable reviews.

## Text exploration

`02_text_exploration.R` tokenizes text, handles stopwords, computes unigram and bigram frequencies, constructs review-level TF-IDF scores using `tidytext`, and explores city-level means of review TF-IDF. A high city-level mean score does not demonstrate a word is unique to that city.

## Dictionary-based sentiment

`03_sentiment_and_negation.R` matches review tokens to the Bing dictionary. A positive match contributes +1; a negative match, −1. The raw score is positive minus negative matches. When at least one word matches, the normalized score is `(positive − negative) / (positive + negative)`. A review with no matches has undefined normalized sentiment (`NA`), not neutral sentiment. Separate outputs distinguish no-match and tie cases. The recorded Spearman correlation with star rating is 0.513.

## UDPipe linguistic analysis

`04_udpipe_pos_optional.R` annotates up to 250 reviews to demonstrate `upos` (nouns/adjectives/verbs) and lemmas. It additionally annotates reviews mentioning `burger`/`burgers`, counts adjectives in the same sentence, and separately extracts direct `amod` adjective modifiers. **Same-sentence co-occurrence is not equivalent to a grammatical link or an opinion directed at the burger.** Predicative cases such as “the burger was cold” may not be captured by the direct `amod` approach.

## Supervised model

`05_supervised_model.R` excludes three-star reviews and creates labels `negative` (1–2 stars) and `positive` (4–5 stars), *derived from the star rating*. The dataset's optional `sentiment` field is not used as a separate independent label.

- Remove identical texts before the train/test split to reduce exact-text leakage.
- Balance the sample with up to 1,200 reviews per class (2,400 reviews in the recorded run).
- Create an 80/20 split within each class (1,920 train, 480 test).
- Learn unigrams/bigrams and IDF weights only from the training corpus; apply the fitted representation unchanged to test reviews.
- Fit an L1-penalized binary logistic regression using `glmnet::cv.glmnet`, with 5-fold cross-validation on train to choose `lambda.min`.
- Classify test reviews using a 0.50 probability threshold.

## Evaluation

The recorded confusion matrix is:

| Actual \ Predicted | Negative | Positive |
|---|---:|---:|
| Negative | 220 | 20 |
| Positive | 19 | 221 |

This gives 441 correct predictions out of 480 reviews. Accuracy = **0.91875**, F1 = **0.9189**, ROC AUC = **0.9694**, Brier score = **0.07948**. The Bing lexicon accuracy on the same test set is **0.68958**, counting abstentions as errors; its abstention rate is **0.07292**. The comparison therefore mixes a classifier forced to make a decision with a lexicon method that may abstain.

**Interpretation:** The text-feature logistic classifier outperforms this fixed lexicon decision rule for this one test sample and rating-polarity task. It does not establish causal explanation of word effects, generalize automatically to other populations, or prove that supervised models are always superior.

## Potential extensions

A second split or nested cross-validation for uncertainty; held-out restaurant groups to reduce shared-restaurant similarity; sensitivity to the 0.50 threshold; calibrated probabilities on natural class proportions; and a stronger aspect-level sentiment analysis using dependency links around nouns.
