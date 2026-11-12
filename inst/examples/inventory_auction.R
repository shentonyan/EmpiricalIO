# A single buyer facing exogenous rival-bid thresholds. Uses base R only.
inventory_model <- function(capacity = 3L, demand_prob = 0.6,
                            prices = c(0.25, 0.75, 1.25, 1.75),
                            price_probs = rep(0.25, 4),
                            bids = c(0, 0.5, 1, 1.5, 2),
                            revenue = 2.4, fee = 0.08, holding = 0.08,
                            discount = 0.95) {
  scalars <- c(capacity, demand_prob, revenue, fee, holding, discount)
  if (any(lengths(list(capacity, demand_prob, revenue, fee, holding, discount)) != 1L) ||
      any(!is.finite(scalars)) || capacity < 1 || capacity != floor(capacity) ||
      demand_prob < 0 || demand_prob > 1 || revenue < 0 || fee < 0 || holding < 0 ||
      discount < 0 || discount >= 1) stop("Invalid inventory model parameters.")
  if (!length(prices) || length(prices) != length(price_probs) ||
      any(!is.finite(c(prices, price_probs, bids))) || any(prices <= 0) ||
      any(price_probs < 0) || abs(sum(price_probs) - 1) > 1e-12 ||
      !length(bids) || bids[1L] != 0 || any(diff(bids) <= 0)) {
    stop("Use positive prices, probabilities summing to one, and increasing bids starting at zero.")
  }
  states <- 0:capacity
  ns <- length(states)
  na <- length(bids)
  reward <- matrix(-Inf, ns, na)
  transition <- array(0, c(ns, na, ns))
  for (s in states) {
    for (a in seq_along(bids)) {
      if (s == capacity && bids[a] > 0) next
      reward[s + 1L, a] <- 0
      enter <- bids[a] > 0
      for (j in seq_along(prices)) {
        win <- as.integer(enter && prices[j] <= bids[a])
        for (d in 0:1) {
          probability <- price_probs[j] * if (d == 1) demand_prob else 1 - demand_prob
          served <- min(s + win, d)
          next_s <- s + win - served
          payoff <- revenue * served - win * prices[j] - fee * enter - holding * next_s
          reward[s + 1L, a] <- reward[s + 1L, a] + probability * payoff
          transition[s + 1L, a, next_s + 1L] <-
            transition[s + 1L, a, next_s + 1L] + probability
        }
      }
    }
  }
  list(states = states, bids = bids, reward = reward, transition = transition,
       capacity = capacity, demand_prob = demand_prob, prices = prices,
       price_probs = price_probs, revenue = revenue, fee = fee,
       holding = holding, discount = discount)
}

inventory_q <- function(model, value) {
  q <- model$reward
  for (s in seq_along(model$states)) {
    for (a in seq_along(model$bids)) {
      if (is.finite(q[s, a])) {
        q[s, a] <- q[s, a] + model$discount * sum(model$transition[s, a, ] * value)
      }
    }
  }
  q
}

solve_inventory <- function(model, tolerance = 1e-10, max_iter = 10000L) {
  if (length(tolerance) != 1L || !is.finite(tolerance) || tolerance <= 0 ||
      length(max_iter) != 1L || !is.finite(max_iter) ||
      max_iter < 1 || max_iter != floor(max_iter)) stop("Invalid solver controls.")
  value <- numeric(length(model$states))
  for (iteration in seq_len(max_iter)) {
    value <- apply(inventory_q(model, value), 1, max)
    q <- inventory_q(model, value)
    residual <- max(abs(apply(q, 1, max) - value))
    if (residual <= tolerance) {
      # The first maximizing action selects the lower bid in a tie.
      action <- max.col(q, ties.method = "first")
      return(list(value = value, action = action, bid = model$bids[action],
                  iterations = iteration, residual = residual,
                  error_bound = residual / (1 - model$discount)))
    }
  }
  stop("Inventory solver did not converge.")
}

inventory_shocks <- function(model, periods, seed) {
  if (length(periods) != 1L || !is.finite(periods) || periods < 1 ||
      periods != floor(periods)) stop("periods must be a positive integer.")
  set.seed(seed)
  data.frame(price = sample(model$prices, periods, replace = TRUE, prob = model$price_probs),
             demand = rbinom(periods, 1, model$demand_prob))
}

simulate_inventory <- function(model, action, shocks, initial_stock = 0L) {
  if (length(action) != length(model$states) || any(!is.finite(action)) ||
      any(action != floor(action)) || any(action < 1 | action > length(model$bids)) ||
      any(!is.finite(model$reward[cbind(seq_along(action), action)]))) {
    stop("Policy must select a feasible action in each state.")
  }
  if (length(initial_stock) != 1L || !is.finite(initial_stock) ||
      initial_stock < 0 || initial_stock > model$capacity ||
      initial_stock != floor(initial_stock)) stop("Invalid initial inventory.")
  if (!all(c("price", "demand") %in% names(shocks)) ||
      any(!is.finite(as.matrix(shocks[c("price", "demand")])) ) ||
      any(!shocks$price %in% model$prices) || any(!shocks$demand %in% 0:1)) {
    stop("Shocks must contain model prices and binary demand.")
  }
  n <- nrow(shocks)
  start <- end <- bid <- win <- served <- profit <- numeric(n)
  stock <- initial_stock
  for (t in seq_len(n)) {
    start[t] <- stock
    bid[t] <- model$bids[action[stock + 1L]]
    enter <- bid[t] > 0
    win[t] <- as.integer(enter && shocks$price[t] <= bid[t])
    served[t] <- min(stock + win[t], shocks$demand[t])
    stock <- stock + win[t] - served[t]
    end[t] <- stock
    profit[t] <- model$revenue * served[t] - win[t] * shocks$price[t] -
      model$fee * enter - model$holding * stock
  }
  data.frame(period = seq_len(n), start, bid, price = shocks$price,
             demand = shocks$demand, win, served, end, profit)
}

run_inventory_example <- function(output_dir, repetitions = 30L, periods = 2000L,
                                  burn_in = 200L, seed = 20261113L, verbose = TRUE) {
  controls <- c(repetitions, periods, burn_in)
  if (any(lengths(list(repetitions, periods, burn_in)) != 1L) ||
      any(!is.finite(controls)) || any(controls != floor(controls)) ||
      repetitions < 2 || periods < 1 || burn_in < 0) {
    stop("Use at least two replications, positive periods, and nonnegative burn-in.")
  }
  model <- inventory_model()
  optimal <- solve_inventory(model)
  myopic_model <- model
  myopic_model$discount <- 0
  myopic <- solve_inventory(myopic_model)
  policies <- list(dynamic = optimal$action, myopic = myopic$action,
                   no_participation = rep(1L, length(model$states)))
  policy <- data.frame(inventory = model$states, dynamic_bid = optimal$bid,
                       myopic_bid = myopic$bid, dynamic_value = optimal$value)
  runs <- vector("list", repetitions * length(policies))
  index <- 0L
  for (replication in seq_len(repetitions)) {
    shocks <- inventory_shocks(model, periods + burn_in, seed + replication - 1L)
    for (name in names(policies)) {
      path <- simulate_inventory(model, policies[[name]], shocks)
      path <- path[seq.int(burn_in + 1L, burn_in + periods), ]
      index <- index + 1L
      runs[[index]] <- data.frame(replication, policy = name,
        profit = mean(path$profit), participation = mean(path$bid > 0),
        fill_rate = if (sum(path$demand) > 0) sum(path$served) / sum(path$demand) else NA_real_,
        inventory = mean(path$end))
    }
  }
  runs <- do.call(rbind, runs)
  summary <- do.call(rbind, lapply(names(policies), function(name) {
    rows <- runs[runs$policy == name, ]
    data.frame(policy = name, mean_profit = mean(rows$profit),
      profit_se = sd(rows$profit) / sqrt(nrow(rows)),
      participation = mean(rows$participation), fill_rate = mean(rows$fill_rate),
      mean_inventory = mean(rows$inventory))
  }))
  paired <- runs$profit[runs$policy == "dynamic"] - runs$profit[runs$policy == "myopic"]
  comparison <- data.frame(comparison = "dynamic minus myopic",
                           mean_profit_difference = mean(paired),
                           standard_error = sd(paired) / sqrt(length(paired)))
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  write.csv(policy, file.path(output_dir, "policy.csv"), row.names = FALSE)
  write.csv(runs, file.path(output_dir, "replications.csv"), row.names = FALSE)
  write.csv(summary, file.path(output_dir, "summary.csv"), row.names = FALSE)
  write.csv(comparison, file.path(output_dir, "paired-comparison.csv"), row.names = FALSE)
  writeLines(c(capture.output(dput(model[c("capacity", "demand_prob", "prices", "price_probs",
                                         "bids", "revenue", "fee", "holding", "discount")])),
               paste("seed:", seed), paste("repetitions:", repetitions),
               paste("periods per replication:", periods), paste("burn-in:", burn_in),
               paste("Bellman residual:", format(optimal$residual, digits = 16)),
               paste("Value error bound:", format(optimal$error_bound, digits = 16)),
               R.version.string), file.path(output_dir, "settings.txt"))
  png(file.path(output_dir, "inventory-auction.png"), width = 1600, height = 700, res = 150)
  par(mfrow = c(1, 2), mar = c(4.5, 4.5, 2.5, 1))
  matplot(policy$inventory, policy[c("dynamic_bid", "myopic_bid")],
          type = "b", lty = c(1, 2), pch = c(16, 1), col = c("#24577A", "#A35A28"),
          xlab = "Beginning inventory", ylab = "Bid", main = "Optimal bids on the grid")
  legend("topright", c("Dynamic", "Myopic"), col = c("#24577A", "#A35A28"),
         lty = c(1, 2), pch = c(16, 1), bty = "n")
  half_width <- qt(0.975, repetitions - 1) * summary$profit_se
  centers <- barplot(summary$mean_profit, names.arg = c("Dynamic", "Myopic", "No bids"),
                      col = c("#24577A", "#A35A28", "#9A9A9A"),
                      ylim = range(c(0, summary$mean_profit - half_width,
                                     summary$mean_profit + half_width)) + c(-0.03, 0.03),
                      ylab = "Mean profit per period", main = "Simulated outcomes")
  valid <- half_width > 0
  arrows(centers[valid], (summary$mean_profit - half_width)[valid],
         centers[valid], (summary$mean_profit + half_width)[valid],
         angle = 90, code = 3, length = 0.05)
  dev.off()
  if (verbose) {
    print(policy, row.names = FALSE)
    print(summary, row.names = FALSE)
    print(comparison, row.names = FALSE)
    message("Results written to ", normalizePath(output_dir, winslash = "/"))
  }
  invisible(list(model = model, solution = optimal, policy = policy,
                 summary = summary, comparison = comparison, replications = runs))
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) > 1L) stop("Usage: Rscript --vanilla inst/examples/inventory_auction.R [output_dir]")
  run_inventory_example(if (length(args)) args[[1L]] else "outputs/inventory-auction")
}
