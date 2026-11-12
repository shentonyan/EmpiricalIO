if (file.exists("R/a7_functions.R")) {
  source("R/a7_functions.R")
  suppressPackageStartupMessages(library(foreach))
  suppressPackageStartupMessages(library(magrittr))
} else {
  library(EmpiricalIO)
}

# An independent Bellman iteration provides the reference value function.
reference_value <- function(PI, G, L, K, delta) {
  V <- rep(0, L)
  for (iteration in seq_len(10000)) {
    next_V <- vapply(seq_len(L), function(s) {
      rows <- (s - 1) * (K + 1) + seq_len(K + 1)
      q <- as.numeric(PI[rows]) + delta * as.numeric(G[rows, , drop = FALSE] %*% V)
      -digamma(1) + max(q) + log(sum(exp(q - max(q))))
    }, numeric(1))
    if (max(abs(next_V - V)) < 1e-12) return(next_V)
    V <- next_V
  }
  stop("Reference Bellman iteration failed.")
}

L <- 5
K <- 1
PI <- compute_PI(0.5, 3, L, K)
G <- compute_G(0.1, 0.6, L, K)
fit <- solve_dynamic_decision(PI, G, L, K, 0.95, 1e-10)
reference <- reference_value(PI, G, L, K, 0.95)
stopifnot(isTRUE(all.equal(as.numeric(fit$V), reference, tolerance = 1e-9)),
          fit$converged, fit$residual <= 1e-10,
          max(abs(colSums(matrix(fit$p, nrow = K + 1)) - 1)) < 1e-14)

# Common utility shifts must not change probabilities, even at large levels.
p <- compute_ccp(fit$V, PI, G, L, K, 0.95)
p_shift <- compute_ccp(fit$V, PI + 10000, G, L, K, 0.95)
stopifnot(all(is.finite(p_shift)),
          isTRUE(all.equal(p, p_shift, tolerance = 1e-10)))

# Three actions exercise the initialization beyond the original binary case.
K <- 2
PI <- compute_PI(0.5, 1, L, K)
G <- compute_G(0.1, 0.3, L, K)
fit <- solve_dynamic_decision(PI, G, L, K, 0.9, 1e-10)
reference <- reference_value(PI, G, L, K, 0.9)
stopifnot(isTRUE(all.equal(as.numeric(fit$V), reference, tolerance = 1e-9)),
          max(abs(colSums(matrix(fit$p, nrow = K + 1)) - 1)) < 1e-14)

# With no continuation payoff the log-sum-exp solution is exact.
fit <- solve_dynamic_decision(PI, G, L, K, 0, 1e-10)
stopifnot(isTRUE(all.equal(as.numeric(fit$V),
                          reference_value(PI, G, L, K, 0), tolerance = 1e-10)))
expect_error <- function(expr, pattern) {
  error <- tryCatch({ force(expr); NULL }, error = identity)
  stopifnot(inherits(error, "error"),
            grepl(pattern, conditionMessage(error), fixed = TRUE))
}
expect_error(solve_dynamic_decision(PI, G, L, K, 0.9, 1e-10, max_iter = 1),
             "did not converge")
expect_error(solve_dynamic_decision(PI, G, L, K, 1, 1e-10), "discount factor")
expect_error(solve_dynamic_decision(PI, G * 2, L, K, 0.9, 1e-10), "row-stochastic")
message("Dynamic decision regression checks passed.")
