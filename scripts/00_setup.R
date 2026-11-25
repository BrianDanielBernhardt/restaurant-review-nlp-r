# Step 0: install required R packages once (including UDPipe for Script 04).
# Run from project root: source("scripts/00_setup.R")
options(repos = c(CRAN = "https://cloud.r-project.org"))
core_packages <- c("readr", "dplyr", "tidyr", "tibble", "stringr", "ggplot2",
                   "tidytext", "text2vec", "glmnet", "Matrix", "zip", "wordcloud", "udpipe")
missing <- setdiff(core_packages, rownames(installed.packages()))
if (length(missing)) install.packages(missing)
for (p in core_packages) {
  if (!requireNamespace(p, quietly = TRUE)) stop("Missing required package: ", p)
}
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/private", recursive = TRUE, showWarnings = FALSE)
dir.create("models", recursive = TRUE, showWarnings = FALSE)
cat("Core packages ready. R: ", R.version.string, "\n", sep = "")
cat("UDPipe package ready; its English model downloads on first use.\n")
cat("Wordcloud package included for the Script 02 exercise.\n")


# Helper functions merged here for a simpler classroom setup.
# Small functions reused across the scripts. No network calls.
ensure_output <- function() {
  for (p in c("outputs/tables", "outputs/figures", "outputs/private"))
    dir.create(p, showWarnings = FALSE, recursive = TRUE)
}
save_course_plot <- function(plot, filename, width = 10, height = 6) {
  ensure_output()
  ggplot2::ggsave(file.path("outputs/figures", filename), plot = plot,
                  width = width, height = height, dpi = 180, bg = "white")
}
safe_ratio <- function(a, b) ifelse(b == 0, NA_real_, a / b)
# Default-palette background in all exported images is white.
course_theme <- function(base_size = 13) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(plot.title.position = "plot", plot.title = ggplot2::element_text(face="bold"),
                   panel.grid.minor = ggplot2::element_blank(),
                   strip.text = ggplot2::element_text(face = "bold"))
}
