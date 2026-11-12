# Run from the repository root with Rscript --vanilla tests/auction.R.
if (file.exists("R/a9_functions.R")) {
  source("R/a9_functions.R")
} else {
  library(EmpiricalIO)
}

# Uniform IPV values have b(x) = (n - 1) * x / n when r = 0.
for (n in c(2, 3, 5)) {
  x <- c(0, 0.01, 0.25, 0.7, 1)
  bids <- vapply(x, bid_first, numeric(1), r = 0,
                 alpha = 1, beta = 1, n = n)
  stopifnot(isTRUE(all.equal(bids, (n - 1) * x / n,
                             tolerance = 1e-9)))
  recovered <- vapply(bids, inverse_bid_first, numeric(1), r = 0,
                     alpha = 1, beta = 1, n = n)
  stopifnot(isTRUE(all.equal(recovered, x, tolerance = 1e-8)))
}

# With a positive reserve, the uniform-value solution is also explicit.
r <- 0.2
n <- 3
x <- c(r, 0.21, 0.5, 1)
expected <- (n - 1) * x / n + r^n / (n * x^(n - 1))
bids <- vapply(x, bid_first, numeric(1), r = r,
               alpha = 1, beta = 1, n = n)
stopifnot(isTRUE(all.equal(bids, expected, tolerance = 1e-9)))
recovered <- vapply(bids, inverse_bid_first, numeric(1), r = r,
                   alpha = 1, beta = 1, n = n)
stopifnot(isTRUE(all.equal(recovered, x, tolerance = 1e-8)))

# Check non-uniform values and the existing inactive-bidder convention.
for (r in c(0, 0.15)) {
  x <- c(r, r + 0.02, 0.6, 0.95)
  bids <- vapply(x, bid_first, numeric(1), r = r,
                 alpha = 2, beta = 3, n = 4)
  recovered <- vapply(bids, inverse_bid_first, numeric(1), r = r,
                     alpha = 2, beta = 3, n = 4)
  stopifnot(isTRUE(all.equal(recovered, x, tolerance = 1e-8)))
  stopifnot(all(bids >= r), all(bids <= x))
}
stopifnot(bid_first(0.1, 0.2, 1, 1, 2) == 0)
stopifnot(isTRUE(all.equal(bid_first(0.8, 0.2, 1, 1, 1), 0.2)))

expect_error <- function(expr, pattern) {
  error <- tryCatch({ force(expr); NULL }, error = identity)
  stopifnot(inherits(error, "error"),
            grepl(pattern, conditionMessage(error), fixed = TRUE))
}
expect_error(inverse_bid_first(0.1, 0, 1, 1, 1), "n >= 2")
expect_error(inverse_bid_first(-0.1, 0, 1, 1, 2), "support")
expect_error(inverse_bid_first(0.6, 0, 1, 1, 2), "support")
message("Auction regression checks passed.")
