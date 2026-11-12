# EmpiricalIO

Lecture notes, R/C++ functions, and exercises for Kohei Kawaguchi's
ECON5630 course on empirical industrial organization. The topics include
production, demand, mergers, entry, dynamic decisions, and auctions.

The [rendered lecture notes](https://kohei-kawaguchi.github.io/EmpiricalIO/)
are maintained by the original author. This repository is a fork of
[kohei-kawaguchi/EmpiricalIO](https://github.com/kohei-kawaguchi/EmpiricalIO).

## Installation

Clone this fork over HTTPS, or replace the URL with the upstream repository:

```bash
git clone https://github.com/shentonyan/EmpiricalIO.git
cd EmpiricalIO
```

Run the commands below from the repository root.

The existing `renv.lock` records R 4.3.0 and the course dependencies. To
restore that environment and install the package:

```sh
Rscript main/install_packages.R
```

The package contains C++ code and needs a compiler compatible with your R
version: Rtools on Windows, the command line tools on macOS, or the R
development tools and a C++ compiler on Linux. Keep the existing lockfile
when reproducing the course results; test dependency upgrades separately.

For an installation without `renv`, install the dependencies listed in
`DESCRIPTION`, then run `R CMD INSTALL --preclean .`. If you edit exported
C++ functions, first regenerate the bindings with `Rcpp::compileAttributes()`.

## Check the auction functions

The auction regression checks use base R and can run without installing
the package or compiling C++:

```sh
Rscript --vanilla tests/auction.R
```

They compare uniform-value auctions with analytic bidding solutions and
check inversion, reserve-price endpoints, and invalid bids. A failed check
returns a nonzero exit status.

## Usage

The source files of the lecture notes are in `/lecture`.

The source files for assignments are in `/lecture` and in `/assignment`. Files in `/lecture` are compiled as chapters of the entire book. Files in `/assignment` can be compiled separately.

The R functions used in the assignments are defined in files in `/R`.

To build the lecture notes, install the lecture dependencies and Pandoc.
PDF output also needs XeLaTeX and the packages used by `lecture/preamble.tex`.

```sh
Rscript main/build_book.R html
Rscript main/build_book.R pdf
```

Both formats are written to `docs/`. For a local preview, use
`Rscript main/build_book.R serve`; the preview server runs until stopped.
Assignments contain simulations and estimation, so building the complete
book can take substantially longer than running the regression checks.
