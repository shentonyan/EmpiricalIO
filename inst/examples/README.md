# Inventory and auction example

From the repository root:

```sh
Rscript --vanilla tests/inventory-auction.R
Rscript --vanilla inst/examples/inventory_auction.R outputs/inventory-auction
```

The first command checks transition probabilities, an analytic no-demand
case, myopic optimization, policy evaluation, and simulated stock accounting.
The second solves the baseline model and compares policies over repeated
simulated paths. It requires base R only.

`inventory-auction.Rmd` states the timing, Bellman equation, parameter
values, simulation design, and interpretation of the reported error bounds.
Render it with `rmarkdown::render("inst/examples/inventory-auction.Rmd")`.

The buyer faces an exogenous distribution of rival-bid thresholds. Prices
and demand are synthetic, and the policy is optimal only within the
specified single-agent model and finite bid grid.
