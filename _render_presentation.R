system("quarto render code_review_presentation.qmd")
file.copy(
  "code_review_presentation.html",
  "_book/code_review_presentation.html",
  overwrite = TRUE
)

# scripts to run before rendering the website

# Load required packages
library(quarto)

# render Introduction to ICPE 2025 course
quarto::quarto_render(
  input = "code_review_presentation.qmd",
  output_format = "revealjs",
  output_file = "code_review_presentation.html"
)
