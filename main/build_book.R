# Run from the repository root: Rscript main/build_book.R [html|pdf|serve]
build_lecture <- function(format = "html") {
  if (!file.exists("lecture/_bookdown.yml")) {
    stop("Run this script from the repository root.")
  }
  if (!format %in% c("html", "pdf", "serve")) {
    stop("Choose html, pdf, or serve.")
  }
  if (!requireNamespace("bookdown", quietly = TRUE)) {
    stop("Install the lecture dependencies before building the book.")
  }
  if (format == "serve") return(bookdown::serve_book(dir = "lecture"))

  dir.create("docs", showWarnings = FALSE)
  file.create("docs/.nojekyll")
  previous_dir <- setwd("lecture")
  on.exit(setwd(previous_dir))
  bookdown::render_book(
    "index.Rmd",
    output_format = if (format == "html") "bookdown::gitbook" else "bookdown::pdf_book",
    clean = TRUE
  )
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 1L) stop("Usage: Rscript main/build_book.R [html|pdf|serve]")
build_lecture(if (length(args)) args[[1L]] else "html")

