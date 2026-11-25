# Dataset terms, sharing, and limitations

## Source

This project uses a restaurant-review extract from [Zenodo DOI 10.5281/zenodo.18723813](https://doi.org/10.5281/zenodo.18723813). The record describes its origin as the Yelp Open Dataset. Please consult both the record and the terms governing your access to the original data, including [Yelp Dataset Terms of Use](https://s3-media0.fl.yelpcdn.com/assets/srv0/engineering_pages/dc1cabe7cb95/assets/vendor/Dataset_User_Agreement.pdf).

## Public repository checklist

- Do not commit raw review text or original data files without a separate affirmative redistribution right.
- Do not commit downloaded language-model binaries whose redistribution terms you have not reviewed.
- Avoid review-level or restaurant-level identifiers, prediction files, and text excerpts that could reconstruct source records.
- **Review applicable Yelp terms before publishing derived charts, statistics, slides, or a publicly visible repository.** Some dataset agreements contain requirements for review/approval before academic results that involve the dataset or brand are published. Keeping the GitHub repository **private initially** is the cautious option until publication conditions are satisfied.
- The project does not claim endorsement by Yelp.

## Interpretation limitations

- Star ratings are used as target labels, rather than manually annotated sentiment. Neutral 3-star records are omitted from supervised analysis.
- Dictionary polarity counts are context-insensitive and may mishandle negation, sarcasm, domain meaning, or mixed opinions.
- The logistic experiment balances the classes and evaluates one hold-out sample; the natural review population may differ in class proportions and temporal/restaurateur characteristics.
- The L1 coefficients are associations conditional on other text features, not causal explanations.
- Burger adjective sentence co-occurrence is exploratory, not an accurate measure of sentiment specifically about burger quality; `amod` links are narrower but incomplete for predicate constructions.

## Licensing

The code and charts belong to different potential rights categories than the original review dataset. This draft intentionally does not assign a code license. A permissive license can be added if the repository owner chooses; no code license should be interpreted as extending to third-party Yelp data.
