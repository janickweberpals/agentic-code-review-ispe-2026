library(quarto)

quarto::quarto_render(
  input         = "code_review_presentation.qmd",
  output_format = "revealjs",
  output_file   = "code_review_presentation.html"
)

file.copy(
  from      = "code_review_presentation.html",
  to        = "_book/code_review_presentation.html",
  overwrite = TRUE
)
