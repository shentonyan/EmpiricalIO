# Run from the repository root. This restores, rather than updates, renv.lock.
if (!file.exists("renv.lock") || !file.exists("DESCRIPTION")) {
  stop("Run this script from the repository root.")
}
if (identical(getOption("repos")[["CRAN"]], "@CRAN@")) {
  options(repos = c(CRAN = "https://cloud.r-project.org"))
}
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
renv::restore(project = ".", prompt = FALSE)
renv::load(project = ".")
renv::install(".")
