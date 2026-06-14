# scripts to run before rendering the website

# Load required packages
library(quarto)

# render GitHub Copilot presentation
quarto::quarto_render(
  input = "code_review_presentation.qmd",
  output_format = "revealjs",
  output_file = "code_review_presentation.qmd"
)
