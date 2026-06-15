# ==============================================================================
# test_primary_endpoint_analysis.R
#
# Integration-style unit tests for the analytical pipeline implemented in
# mock-study/03_primary_endpoint_analysis.qmd.
#
# Strategy: extract and re-run each analytical step in isolation so that
# errors surface with a clear label rather than buried in Quarto output.
#
# Run via: testthat::test_file("test/test_primary_endpoint_analysis.R")
#          testthat::test_dir("test/")
# ==============================================================================

library(testthat)
library(dplyr)
library(WeightIt)
library(cobalt)
library(survival)
library(survey)

source(here::here("mock-study", "02_data_generation.R"))

# Use a smaller cohort for test speed; seed matches the analysis default.
cohort <- generate_cohort(n = 3000, seed = 20260614)

covariates <- c(
  "age", "female", "race", "region",
  "bmi", "prior_hf_hosp", "diuretic_use",
  "nephropathy", "neuropathy", "retinopathy", "foot_ulcer", "insulin_use",
  "pad", "afib", "cardiomyopathy", "ckd",
  "copd", "depression", "dementia",
  "metformin", "sulfonylurea", "sglt2i", "statin", "anticoagulant",
  "n_hospitalizations", "n_ed_visits", "n_distinct_meds", "comorbidity_index"
)

# ==============================================================================
# 1. Covariate specification
# ==============================================================================

test_that("every covariate in the adjustment set exists in the cohort", {
  expect_true(all(covariates %in% names(cohort)))
})

test_that("covariate list contains no duplicates", {
  expect_equal(length(covariates), length(unique(covariates)))
})

test_that("PS formula is a valid formula object with 'treatment' as response", {
  ps_formula <- reformulate(covariates, response = "treatment")
  expect_s3_class(ps_formula, "formula")
  expect_equal(deparse(ps_formula[[2]]), "treatment")
  expect_equal(length(attr(terms(ps_formula), "term.labels")), length(covariates))
})

# ==============================================================================
# 2. Propensity-score overlap (ATO) weighting
# ==============================================================================

W <- weightit(
  reformulate(covariates, response = "treatment"),
  data     = cohort,
  method   = "glm",
  estimand = "ATO"
)
cohort$ato_weight <- W$weights

test_that("weightit produces one weight per patient", {
  expect_equal(length(W$weights), nrow(cohort))
})

test_that("ATO weights are strictly positive", {
  expect_true(all(W$weights > 0))
})

test_that("ATO weights are less than 1 (overlap weight property: w = ps or 1-ps)", {
  expect_true(all(W$weights < 1))
})

test_that("effective sample size is reduced but not trivially small", {
  ess <- sum(W$weights)^2 / sum(W$weights^2)
  expect_lt(ess, nrow(cohort))
  expect_gt(ess, nrow(cohort) * 0.10)
})

# ==============================================================================
# 3. Covariate balance after weighting
# ==============================================================================

test_that("all absolute SMDs are below 0.10 after ATO weighting", {
  bal  <- bal.tab(W, stats = "mean.diffs")
  smds <- abs(bal$Balance[["Diff.Adj"]])
  expect_true(all(smds < 0.10, na.rm = TRUE))
})

test_that("mean absolute SMD after weighting is well below 0.05", {
  bal  <- bal.tab(W, stats = "mean.diffs")
  smds <- abs(bal$Balance[["Diff.Adj"]])
  expect_lt(mean(smds, na.rm = TRUE), 0.05)
})

test_that("ATO weighting reduces maximum SMD compared with unweighted", {
  bal       <- bal.tab(W, stats = "mean.diffs")
  max_adj   <- max(abs(bal$Balance[["Diff.Adj"]]),  na.rm = TRUE)
  max_unadj <- max(abs(bal$Balance[["Diff.Un"]]),   na.rm = TRUE)
  expect_lt(max_adj, max_unadj)
})

# ==============================================================================
# 4. Weighted Cox proportional-hazards model
# ==============================================================================

cox_wt <- coxph(
  Surv(time, status) ~ treatment_label,
  data    = cohort,
  weights = cohort$ato_weight,
  robust  = TRUE
)

test_that("Cox model produces finite coefficients (convergence check)", {
  expect_true(all(is.finite(coef(cox_wt))))
})

test_that("treatment_labelDrug A coefficient is present in the model", {
  expect_true("treatment_labelDrug A" %in% names(coef(cox_wt)))
})

test_that("ATO-weighted HR for Drug A vs Drug B is in plausible range (0.5, 1.5)", {
  hr <- exp(coef(cox_wt))[["treatment_labelDrug A"]]
  expect_gt(hr, 0.50)
  expect_lt(hr, 1.50)
})

test_that("95% CI is finite and correctly ordered (lower < upper)", {
  ci <- exp(confint(cox_wt))["treatment_labelDrug A", ]
  expect_true(all(is.finite(ci)))
  expect_lt(ci[[1]], ci[[2]])
})

test_that("robust standard errors are positive and finite", {
  robust_se <- sqrt(diag(cox_wt$var))
  expect_true(all(is.finite(robust_se)))
  expect_true(all(robust_se > 0))
})

# ==============================================================================
# 5. One-year cumulative incidence (weighted Kaplan-Meier)
# ==============================================================================

fit_wt   <- survfit(
  Surv(time, status) ~ treatment_label,
  data    = cohort,
  weights = cohort$ato_weight
)
risk_1yr <- summary(fit_wt, times = 365)

test_that("survfit produces exactly two strata (one per treatment arm)", {
  expect_equal(length(fit_wt$strata), 2L)
})

test_that("strata names correspond to Drug A and Drug B", {
  strata_names <- names(fit_wt$strata)
  expect_true(any(grepl("Drug A", strata_names)))
  expect_true(any(grepl("Drug B", strata_names)))
})

test_that("1-year cumulative incidence is between 1% and 10% in each arm", {
  risks <- 1 - risk_1yr$surv
  expect_true(all(risks > 0.01))
  expect_true(all(risks < 0.10))
})

test_that("CI for 1-year risk is ordered: lower <= surv <= upper", {
  expect_true(all(risk_1yr$lower <= risk_1yr$surv  + 1e-10))
  expect_true(all(risk_1yr$surv  <= risk_1yr$upper + 1e-10))
})

test_that("1-year risk point estimates are available for both arms", {
  expect_equal(length(risk_1yr$surv), 2L)
  expect_true(all(is.finite(risk_1yr$surv)))
})

# ==============================================================================
# 6. HR text formatting helper (inline R used in the .qmd)
# ==============================================================================

test_that("hr_text formatting produces a non-empty string matching expected pattern", {
  hr      <- exp(coef(cox_wt))[["treatment_labelDrug A"]]
  ci      <- exp(confint(cox_wt))["treatment_labelDrug A", ]
  hr_text <- sprintf("%.2f (95%% CI, %.2f-%.2f)", hr, ci[1], ci[2])
  expect_type(hr_text, "character")
  expect_match(hr_text, "^[0-9]+\\.[0-9]{2} \\(95% CI, [0-9]+\\.[0-9]{2}-[0-9]+\\.[0-9]{2}\\)$")
})
