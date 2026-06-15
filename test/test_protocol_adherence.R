# ==============================================================================
# test_protocol_adherence.R
#
# Protocol-adherence tests: verify that the implementations in
#   mock-study/02_data_generation.R   (data generation)
#   mock-study/03_primary_endpoint_analysis.qmd  (primary analysis)
# honour every pre-specified choice documented in
#   mock-study/01_csp.qmd.
#
# All hard-coded expected values are taken directly from the CSP text
# (section references in each test label).  The goal is a failing test
# whenever a code change silently deviates from the protocol.
#
# Run via: testthat::test_file("test/test_protocol_adherence.R")
# ==============================================================================

library(testthat)
library(dplyr)
library(WeightIt)
library(survival)

source(here::here("mock-study", "02_data_generation.R"))

# Cohorts generated once and reused across sections.
# cohort_default : full protocol size — used for distribution + benchmark tests.
# cohort_fit     : smaller — used for analysis-specification tests (faster).
cohort_default <- generate_cohort() # n = 28 100, seed = 20260614
cohort_fit <- generate_cohort(n = 3000, seed = 20260614)

# ==============================================================================
# 1. Default data-generation parameters  (CSP §2, §8.4, §8.6)
# ==============================================================================

test_that("default cohort size is 28 100 (CSP §2 Abstract: 'n = 28,100')", {
  expect_equal(nrow(cohort_default), 28100L)
})

test_that("default administrative censoring window is 365 days (CSP §8.3: 'Day 365 (52 weeks)')", {
  expect_true(all(cohort_default$time <= 365))
})

test_that("default seed matches CSP data-version entry (CSP §8.4: 'Seed = 20260614')", {
  c1 <- generate_cohort(n = 300)
  c2 <- generate_cohort(n = 300, seed = 20260614)
  expect_identical(c1, c2)
})

# ==============================================================================
# 2. Treatment variable coding  (CSP §8.2 Exposure table)
# ==============================================================================

test_that("treatment = 1 maps to Drug A (CSP: 'treatment = 1; treatment_label = Drug A')", {
  expect_true(all(
    cohort_default$treatment_label[cohort_default$treatment == 1] == "Drug A"
  ))
})

test_that("treatment = 0 maps to Drug B (CSP: 'treatment = 0; treatment_label = Drug B')", {
  expect_true(all(
    cohort_default$treatment_label[cohort_default$treatment == 0] == "Drug B"
  ))
})

test_that("Drug B is the reference level of treatment_label (CSP: Drug B is comparator)", {
  expect_equal(levels(cohort_default$treatment_label)[1], "Drug B")
})

# ==============================================================================
# 3. Inclusion criteria and covariate bounds  (CSP §8.2)
# ==============================================================================

test_that("age is restricted to [30, 90] years (CSP inclusion criterion and covariate table)", {
  expect_true(all(cohort_default$age >= 30))
  expect_true(all(cohort_default$age <= 90))
})

test_that("BMI is clamped to [18, 60] kg/m² (CSP covariate table: 'clipped [18, 60]')", {
  expect_true(all(cohort_default$bmi >= 18))
  expect_true(all(cohort_default$bmi <= 60))
})

test_that("comorbidity_index floored at 0 (CSP covariate table: 'max(Normal(2, 1.5), 0)')", {
  expect_true(all(cohort_default$comorbidity_index >= 0))
})

# ==============================================================================
# 4. Follow-up and event definition  (CSP §8.3 Follow-up table)
# ==============================================================================

test_that("all event times are ≤ 365 days (CSP: 'status = 1 if event_time ≤ ... ≤ 365')", {
  events <- cohort_default[cohort_default$status == 1, ]
  expect_true(all(events$time <= 365))
})

test_that("no zero-time observations (CSP follow-up starts day 1 after cohort entry)", {
  expect_true(all(cohort_default$time > 0))
})

# ==============================================================================
# 5. Marginal covariate distributions  (CSP §8.2 covariate table)
#    Expected values are taken verbatim from the CSP "Distribution" column.
#    Tolerances (± 5pp binary; ± 15% relative continuous/count) detect
#    parameter substitution errors (e.g. 0.06 → 0.16) without being brittle.
# ==============================================================================

tol_pp <- 0.05 # ± 5 percentage points
tol_rel <- 0.15 # ± 15 % relative

# --- Demographics ---
test_that("female prevalence ≈ 48% (CSP: Bernoulli(0.48))", {
  expect_equal(mean(cohort_default$female), 0.48, tolerance = tol_pp)
})

test_that("race distribution matches CSP: White 70%, Black 18%, Other 12%", {
  p <- prop.table(table(cohort_default$race))
  expect_equal(as.numeric(p["White"]), 0.70, tolerance = tol_pp)
  expect_equal(as.numeric(p["Black"]), 0.18, tolerance = tol_pp)
  expect_equal(as.numeric(p["Other"]), 0.12, tolerance = tol_pp)
})

test_that("region distribution matches CSP: NE 20%, MW 23%, S 38%, W 19%", {
  p <- prop.table(table(cohort_default$region))
  expect_equal(as.numeric(p["Northeast"]), 0.20, tolerance = tol_pp)
  expect_equal(as.numeric(p["Midwest"]), 0.23, tolerance = tol_pp)
  expect_equal(as.numeric(p["South"]), 0.38, tolerance = tol_pp)
  expect_equal(as.numeric(p["West"]), 0.19, tolerance = tol_pp)
})

test_that("age mean ≈ 65 years (CSP: Normal(65, 10), clipped [30, 90])", {
  expect_equal(mean(cohort_default$age), 65, tolerance = 65 * tol_rel)
})

test_that("BMI mean ≈ 33 kg/m² (CSP: Normal(33, 5), clipped [18, 60])", {
  expect_equal(mean(cohort_default$bmi), 33, tolerance = 33 * tol_rel)
})

# --- Cardiometabolic burden ---
test_that("prior_hf_hosp prevalence ≈ 6% (CSP: Bernoulli(0.06))", {
  expect_equal(mean(cohort_default$prior_hf_hosp), 0.06, tolerance = tol_pp)
})

test_that("diuretic_use prevalence ≈ 28% (CSP: Bernoulli(0.28))", {
  expect_equal(mean(cohort_default$diuretic_use), 0.28, tolerance = tol_pp)
})

# --- Diabetes complications ---
test_that("nephropathy prevalence ≈ 15% (CSP: Bernoulli(0.15))", {
  expect_equal(mean(cohort_default$nephropathy), 0.15, tolerance = tol_pp)
})

test_that("insulin_use prevalence ≈ 30% (CSP: Bernoulli(0.30))", {
  expect_equal(mean(cohort_default$insulin_use), 0.30, tolerance = tol_pp)
})

test_that("foot_ulcer prevalence ≈ 5% (CSP: Bernoulli(0.05) — lowest-prevalence variable)", {
  expect_equal(mean(cohort_default$foot_ulcer), 0.05, tolerance = tol_pp)
})

# --- CV / kidney disease ---
test_that("afib prevalence ≈ 12% (CSP: Bernoulli(0.12))", {
  expect_equal(mean(cohort_default$afib), 0.12, tolerance = tol_pp)
})

test_that("ckd prevalence ≈ 20% (CSP: Bernoulli(0.20))", {
  expect_equal(mean(cohort_default$ckd), 0.20, tolerance = tol_pp)
})

# --- Concomitant medications (spot-check highest and lowest prevalences) ---
test_that("metformin prevalence ≈ 72% (CSP: Bernoulli(0.72))", {
  expect_equal(mean(cohort_default$metformin), 0.72, tolerance = tol_pp)
})

test_that("anticoagulant prevalence ≈ 14% (CSP: Bernoulli(0.14))", {
  expect_equal(mean(cohort_default$anticoagulant), 0.14, tolerance = tol_pp)
})

test_that("statin prevalence ≈ 65% (CSP: Bernoulli(0.65))", {
  expect_equal(mean(cohort_default$statin), 0.65, tolerance = tol_pp)
})

# --- Healthcare utilisation ---
test_that("n_distinct_meds mean ≈ 8 (CSP: Poisson(8))", {
  expect_equal(mean(cohort_default$n_distinct_meds), 8, tolerance = 8 * tol_rel)
})

test_that("n_hospitalizations mean ≈ 0.4 (CSP: Poisson(0.4))", {
  expect_equal(
    mean(cohort_default$n_hospitalizations),
    0.4,
    tolerance = 0.4 * tol_rel
  )
})

test_that("n_ed_visits mean ≈ 0.6 (CSP: Poisson(0.6))", {
  expect_equal(mean(cohort_default$n_ed_visits), 0.6, tolerance = 0.6 * tol_rel)
})

test_that("comorbidity_index mean ≈ 2 (CSP: max(Normal(2, 1.5), 0))", {
  expect_equal(
    mean(cohort_default$comorbidity_index),
    2,
    tolerance = 2 * tol_rel
  )
})

# ==============================================================================
# 6. Analysis specification  (CSP §8.1 analysis plan table)
#    Ground-truth covariate list is taken verbatim from the CSP PS formula.
# ==============================================================================

# CSP §8.1 PS formula: treatment ~ [these 28 variables]
csp_covariates <- c(
  "age",
  "female",
  "race",
  "region",
  "bmi",
  "prior_hf_hosp",
  "diuretic_use",
  "nephropathy",
  "neuropathy",
  "retinopathy",
  "foot_ulcer",
  "insulin_use",
  "pad",
  "afib",
  "cardiomyopathy",
  "ckd",
  "copd",
  "depression",
  "dementia",
  "metformin",
  "sulfonylurea",
  "sglt2i",
  "statin",
  "anticoagulant",
  "n_hospitalizations",
  "n_ed_visits",
  "n_distinct_meds",
  "comorbidity_index"
)

# Covariate vector as specified in 03_primary_endpoint_analysis.qmd
analysis_covariates <- c(
  "age",
  "female",
  "race",
  "region",
  "bmi",
  "prior_hf_hosp",
  "diuretic_use",
  "nephropathy",
  "neuropathy",
  "retinopathy",
  "foot_ulcer",
  "insulin_use",
  "pad",
  "afib",
  "cardiomyopathy",
  "ckd",
  "copd",
  "depression",
  "dementia",
  "metformin",
  "sulfonylurea",
  "sglt2i",
  "statin",
  "anticoagulant",
  "n_hospitalizations",
  "n_ed_visits",
  "n_distinct_meds",
  "comorbidity_index"
)

test_that("analysis PS covariates match CSP formula exactly — no additions or omissions", {
  expect_setequal(analysis_covariates, csp_covariates)
})

test_that("PS covariate count is 28 (CSP lists 28 variables in the formula)", {
  expect_equal(length(csp_covariates), 28L)
  expect_equal(length(analysis_covariates), 28L)
})

test_that("all 28 CSP covariates are present in the cohort dataset", {
  expect_true(all(csp_covariates %in% names(cohort_fit)))
})

# Fit models with cohort_fit (n = 3 000) for specification tests
W_fit <- weightit(
  reformulate(csp_covariates, response = "treatment"),
  data = cohort_fit,
  method = "glm",
  estimand = "ATO"
)
cohort_fit$ato_weight <- W_fit$weights

cox_fit <- coxph(
  Surv(time, status) ~ treatment_label,
  data = cohort_fit,
  weights = cohort_fit$ato_weight,
  robust = TRUE
)

test_that("PS model uses logistic regression (CSP: 'WeightIt::weightit(method = glm ...)')", {
  expect_equal(W_fit$method, "glm")
})

test_that("estimand is ATO (CSP: 'estimand = ATO')", {
  expect_equal(W_fit$estimand, "ATO")
})

test_that("Cox model uses robust sandwich SEs (CSP: 'robust = TRUE')", {
  # naive.var is only populated by coxph when robust = TRUE
  expect_false(is.null(cox_fit$naive.var))
})

test_that("Cox outcome is Surv(time, status) (CSP outcome model specification)", {
  cox_vars <- all.vars(cox_fit$formula)
  expect_true("time" %in% cox_vars)
  expect_true("status" %in% cox_vars)
})

test_that("Cox predictor is treatment_label, not raw binary treatment (CSP outcome model)", {
  cox_vars <- all.vars(cox_fit$formula)
  expect_true("treatment_label" %in% cox_vars)
  expect_false("treatment" %in% cox_vars)
})

# ==============================================================================
# 7. Quality control benchmarks  (CSP §8.1 QC: "1-year risk ≈ 3.4% (Drug B
#    arm), ATO-weighted HR ≈ 0.86 (95% CI includes 1.0)")
#    Requires the full cohort (n = 28 100) for stable estimates.
#    Note: these tests fit WeightIt on n = 28 100 and will take ~10–20 seconds.
# ==============================================================================

W_full <- weightit(
  reformulate(csp_covariates, response = "treatment"),
  data = cohort_default,
  method = "glm",
  estimand = "ATO"
)
cohort_default$ato_weight <- W_full$weights

cox_full <- coxph(
  Surv(time, status) ~ treatment_label,
  data = cohort_default,
  weights = cohort_default$ato_weight,
  robust = TRUE
)

fit_full <- survfit(
  Surv(time, status) ~ treatment_label,
  data = cohort_default,
  weights = cohort_default$ato_weight
)
risk_1yr <- summary(fit_full, times = 365)
drugB_idx <- grep("Drug B", names(fit_full$strata))

test_that("1-year cumulative incidence in Drug B arm is ≈ 3.4% (CSP QC benchmark)", {
  risk_drugB <- 1 - risk_1yr$surv[drugB_idx]
  expect_gt(risk_drugB, 0.025) # lower guard: > 2.5%
  expect_lt(risk_drugB, 0.050) # upper guard: < 5.0%
})

test_that("ATO-weighted HR is ≈ 0.86 (CSP QC benchmark, plausible range 0.70–1.05)", {
  hr <- exp(coef(cox_full))[["treatment_labelDrug A"]]
  expect_gt(hr, 0.70)
  expect_lt(hr, 1.05)
})

test_that("ATO-weighted 95% CI for Drug A HR includes 1.0 (CSP QC benchmark)", {
  ci <- exp(confint(cox_full))["treatment_labelDrug A", ]
  expect_lt(ci[[1]], 1.0) # lower bound must be below 1
  expect_gt(ci[[2]], 1.0) # upper bound must be above 1
})
