# ==============================================================================
# test_data_generation.R
#
# Unit tests for mock-study/02_data_generation.R (generate_cohort()).
# Run via: testthat::test_file("test/test_data_generation.R")   # from project root
#          testthat::test_dir("test/")                           # all tests
# ==============================================================================

library(testthat)

source(here::here("mock-study", "02_data_generation.R"))

# Reusable small cohort (fast); larger cohorts only where statistics require it
small  <- generate_cohort(n = 500,  seed = 1)
medium <- generate_cohort(n = 3000, seed = 1)

# ==============================================================================
# 1. Output structure
# ==============================================================================

test_that("returns a tibble with the requested number of rows", {
  out <- generate_cohort(n = 200, seed = 99)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 200)
})

test_that("all expected columns are present", {
  expected_cols <- c(
    "id", "treatment", "treatment_label", "time", "status",
    "age", "female", "race", "region", "bmi",
    "prior_hf_hosp", "diuretic_use",
    "nephropathy", "neuropathy", "retinopathy", "foot_ulcer", "insulin_use",
    "pad", "afib", "cardiomyopathy", "ckd",
    "copd", "depression", "dementia",
    "metformin", "sulfonylurea", "sglt2i", "statin", "anticoagulant",
    "n_hospitalizations", "n_ed_visits", "n_distinct_meds", "comorbidity_index"
  )
  expect_true(all(expected_cols %in% names(small)))
})

test_that("patient IDs are unique and span 1:n", {
  expect_equal(sort(small$id), seq_len(nrow(small)))
})

# ==============================================================================
# 2. Column types and factor levels
# ==============================================================================

test_that("treatment is integer 0/1", {
  expect_true(all(small$treatment %in% c(0L, 1L)))
})

test_that("treatment_label is a factor with levels Drug B (ref) and Drug A", {
  expect_s3_class(small$treatment_label, "factor")
  expect_equal(levels(small$treatment_label), c("Drug B", "Drug A"))
})

test_that("treatment and treatment_label are consistent", {
  expect_equal(
    as.integer(small$treatment_label) - 1L,
    small$treatment
  )
})

test_that("status is integer 0/1", {
  expect_true(all(small$status %in% c(0L, 1L)))
})

test_that("race and region are factors", {
  expect_s3_class(small$race,   "factor")
  expect_s3_class(small$region, "factor")
})

test_that("count variables are non-negative integers", {
  count_cols <- c("n_hospitalizations", "n_ed_visits", "n_distinct_meds")
  for (col in count_cols) {
    expect_true(all(small[[col]] >= 0L), label = paste("non-negative:", col))
    expect_true(all(small[[col]] == floor(small[[col]])), label = paste("integer:", col))
  }
})

# ==============================================================================
# 3. Value ranges
# ==============================================================================

test_that("age is clamped to [30, 90]", {
  expect_true(all(small$age >= 30))
  expect_true(all(small$age <= 90))
})

test_that("BMI is clamped to [18, 60]", {
  expect_true(all(small$bmi >= 18))
  expect_true(all(small$bmi <= 60))
})

test_that("comorbidity_index is non-negative", {
  expect_true(all(small$comorbidity_index >= 0))
})

test_that("follow-up time is positive and within max_fu_days", {
  expect_true(all(small$time > 0))
  expect_true(all(small$time <= 365))
})

test_that("max_fu_days parameter is respected", {
  out <- generate_cohort(n = 300, max_fu_days = 180, seed = 7)
  expect_true(all(out$time <= 180))
})

test_that("all binary comorbidity/medication flags are 0 or 1", {
  binary_cols <- c(
    "female", "prior_hf_hosp", "diuretic_use",
    "nephropathy", "neuropathy", "retinopathy", "foot_ulcer", "insulin_use",
    "pad", "afib", "cardiomyopathy", "ckd",
    "copd", "depression", "dementia",
    "metformin", "sulfonylurea", "sglt2i", "statin", "anticoagulant"
  )
  for (col in binary_cols) {
    expect_true(all(small[[col]] %in% c(0L, 1L)), label = col)
  }
})

# ==============================================================================
# 4. No missing values in key analytical variables
# ==============================================================================

test_that("no NAs in key analytical variables", {
  key_vars <- c("id", "treatment", "treatment_label", "time", "status",
                "age", "bmi", "comorbidity_index")
  for (v in key_vars) {
    expect_false(anyNA(small[[v]]), label = paste("NA check:", v))
  }
})

# ==============================================================================
# 5. Epidemiological plausibility
# ==============================================================================

test_that("treatment prevalence is between 20% and 80%", {
  prev <- mean(medium$treatment)
  expect_gt(prev, 0.20)
  expect_lt(prev, 0.80)
})

test_that("1-year event rate is between 1% and 10%", {
  rate <- mean(medium$status)
  expect_gt(rate, 0.01)
  expect_lt(rate, 0.10)
})

test_that("confounding by indication: Drug A initiators are younger on average", {
  mean_age <- tapply(medium$age, medium$treatment, mean)
  expect_lt(mean_age[["1"]], mean_age[["0"]])
})

test_that("confounding by indication: Drug A initiators have higher mean BMI", {
  mean_bmi <- tapply(medium$bmi, medium$treatment, mean)
  expect_gt(mean_bmi[["1"]], mean_bmi[["0"]])
})

test_that("Drug A initiators have lower prior HF hospitalization rate", {
  hf_rate <- tapply(medium$prior_hf_hosp, medium$treatment, mean)
  expect_lt(hf_rate[["1"]], hf_rate[["0"]])
})

# ==============================================================================
# 6. Reproducibility
# ==============================================================================

test_that("identical seeds produce identical datasets", {
  c1 <- generate_cohort(n = 200, seed = 42)
  c2 <- generate_cohort(n = 200, seed = 42)
  expect_identical(c1, c2)
})

test_that("different seeds produce different treatment assignments", {
  c1 <- generate_cohort(n = 500, seed = 1)
  c2 <- generate_cohort(n = 500, seed = 2)
  expect_false(identical(c1$treatment, c2$treatment))
})
