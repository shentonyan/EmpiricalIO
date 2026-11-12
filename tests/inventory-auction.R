example_path <- if (file.exists("inst/examples/inventory_auction.R")) {
  "inst/examples/inventory_auction.R"
} else {
  system.file("examples/inventory_auction.R", package = "EmpiricalIO")
}
if (!file.exists(example_path)) stop("Run from the repository root or install EmpiricalIO first.")
source(example_path)
model <- inventory_model()
fit <- solve_inventory(model)
feasible <- is.finite(model$reward)
stopifnot(all(model$transition >= 0),
          all(abs(apply(model$transition, c(1, 2), sum)[feasible] - 1) < 1e-12),
          fit$residual <= 1e-10, fit$error_bound <= 2.1e-9)

# Evaluate the selected policy by solving its linear system.
rows <- seq_along(model$states)
P <- do.call(rbind, lapply(rows, function(s) model$transition[s, fit$action[s], ]))
r <- model$reward[cbind(rows, fit$action)]
evaluated <- solve(diag(length(rows)) - model$discount * P, r)
stopifnot(max(abs(fit$value - evaluated)) <= fit$error_bound + 1e-10)

# With no demand, inventory is never depleted and purchases cannot help.
no_demand <- inventory_model(demand_prob = 0)
fit_no_demand <- solve_inventory(no_demand)
stopifnot(all(fit_no_demand$bid == 0),
          max(abs(fit_no_demand$value + no_demand$holding * no_demand$states /
                    (1 - no_demand$discount))) <= fit_no_demand$error_bound + 1e-10)
myopic <- model
myopic$discount <- 0
fit_myopic <- solve_inventory(myopic)
stopifnot(max(abs(fit_myopic$value - apply(model$reward, 1, max))) < 1e-12)

shocks <- inventory_shocks(model, 1000L, 37L)
path <- simulate_inventory(model, fit$action, shocks)
stopifnot(identical(shocks, inventory_shocks(model, 1000L, 37L)),
          all(path$end == path$start + path$win - path$served),
          all(path$end >= 0 & path$end <= model$capacity),
          all(path$served <= path$demand),
          all(path$win == as.integer(path$bid > 0 & path$price <= path$bid)))
expect_error <- function(expr, pattern) {
  error <- tryCatch({ force(expr); NULL }, error = identity)
  stopifnot(inherits(error, "error"),
            grepl(pattern, conditionMessage(error), fixed = TRUE))
}
expect_error(solve_inventory(model, max_iter = 1), "did not converge")
expect_error(inventory_model(discount = 1), "parameters")
expect_error(simulate_inventory(model, rep(5, 4), shocks), "feasible action")
expect_error(run_inventory_example(tempdir(), repetitions = 1), "two replications")
message("Inventory auction regression checks passed.")
