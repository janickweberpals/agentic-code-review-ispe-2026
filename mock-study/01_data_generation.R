# ==============================================================================
# 02_data_generation.R
#
# Target trial emulation: Drug A vs. Drug B in type 2 diabetes (T2DM)
#
# Purpose:  Provide generate_cohort(), a function that returns a SIMULATED cohort
#           mimicking the structure of the head-to-head new-user active-comparator
#           The simulation deliberately builds in *confounding by indication*
#           (Drug A initiators are on average younger / healthier) so that
#           the downstream propensity-score overlap-weighting analysis has
#           something to correct. The data-generating treatment effect is set so
#           that, after balancing, the primary composite endpoint
#           (HF hospitalization OR all-cause mortality) yields an HR ~= 0.86
#           with a 1-year risk of ~3.3%-3.4%.
#
# Usage:    source("02_data_generation.R"); cohort <- generate_cohort()
#           The data are generated in memory and are NOT written to disk.
#
# NOTE:     This is SYNTHETIC data for teaching / code-review purposes only.
#           No real patient data are used.
#           Packages are referenced via the `::` operator (no library() calls).
# ==============================================================================

# ------------------------------------------------------------------------------
# generate_cohort()
#   n           : total cohort size (default 28100, matching the published study)
#   max_fu_days : administrative follow-up window (~52 weeks)
#   true_log_hr : conditional data-generating treatment effect (log HR). Non-
#                 collapsibility attenuates the marginal (weighted) HR toward the
#                 published target of ~0.86.
#   seed        : RNG seed for reproducibility
#   Returns     : a tibble with one row per patient (baseline covariates,
#                 treatment, follow-up time, and event status).
# ------------------------------------------------------------------------------
generate_cohort <- function(n           = 28100,
                            max_fu_days = 365,
                            true_log_hr = log(0.80),
                            seed        = 20260614) {

  set.seed(seed)

  # ----------------------------------------------------------------------------
  # 1. Baseline covariates
  #    Representative subset of the confounders adjusted for in the source study:
  #    demographics, cardiometabolic burden, diabetes complications,
  #    cardiovascular/kidney disease, comorbidities, concomitant medications,
  #    and healthcare utilization.
  # ----------------------------------------------------------------------------
  dat <- dplyr::tibble(id = seq_len(n)) |>
    dplyr::mutate(
      # --- Demographics -----------------------------------------------------
      age       = round(rnorm(n, mean = 65, sd = 10)),
      age       = pmin(pmax(age, 30), 90),
      female    = rbinom(n, 1, 0.48),
      race      = factor(sample(c("White", "Black", "Other"), n,
                                replace = TRUE, prob = c(0.70, 0.18, 0.12))),
      region    = factor(sample(c("Northeast", "Midwest", "South", "West"), n,
                                replace = TRUE, prob = c(0.20, 0.23, 0.38, 0.19))),

      # --- Cardiometabolic burden ------------------------------------------
      bmi             = round(rnorm(n, mean = 33, sd = 5), 1),
      bmi             = pmin(pmax(bmi, 18), 60),
      prior_hf_hosp   = rbinom(n, 1, 0.06),
      diuretic_use    = rbinom(n, 1, 0.28),

      # --- Diabetes complications ------------------------------------------
      nephropathy = rbinom(n, 1, 0.15),
      neuropathy  = rbinom(n, 1, 0.22),
      retinopathy = rbinom(n, 1, 0.12),
      foot_ulcer  = rbinom(n, 1, 0.05),
      insulin_use = rbinom(n, 1, 0.30),

      # --- Cardiovascular / kidney disease ---------------------------------
      pad            = rbinom(n, 1, 0.10),   # peripheral arterial disease
      afib           = rbinom(n, 1, 0.12),
      cardiomyopathy = rbinom(n, 1, 0.07),
      ckd            = rbinom(n, 1, 0.20),

      # --- Other comorbidities ---------------------------------------------
      copd       = rbinom(n, 1, 0.13),
      depression = rbinom(n, 1, 0.18),
      dementia   = rbinom(n, 1, 0.04),

      # --- Concomitant medications -----------------------------------------
      metformin     = rbinom(n, 1, 0.72),
      sulfonylurea  = rbinom(n, 1, 0.35),
      sglt2i        = rbinom(n, 1, 0.30),
      statin        = rbinom(n, 1, 0.65),
      anticoagulant = rbinom(n, 1, 0.14),

      # --- Healthcare utilization (prior year) -----------------------------
      n_hospitalizations = rpois(n, 0.4),
      n_ed_visits        = rpois(n, 0.6),
      n_distinct_meds    = rpois(n, 8),

      # --- Combined comorbidity index (continuous frailty/burden score) ----
      comorbidity_index = round(rnorm(n, mean = 2, sd = 1.5), 2),
      comorbidity_index = pmax(comorbidity_index, 0)
    )

  # ----------------------------------------------------------------------------
  # 2. Treatment assignment (confounding by indication)
  #    Drug A (newer agent) is preferentially initiated in younger patients
  #    with higher BMI and a lower comorbidity burden -> non-random assignment.
  #    treatment = 1 (Drug A), 0 (Drug B)
  # ----------------------------------------------------------------------------
  ps_lp <- with(dat,
    0.30 +
    -0.030 * (age - 65)            +   # younger -> Drug A
     0.040 * (bmi - 33)            +   # higher BMI -> Drug A
    -0.45  * prior_hf_hosp         +   # sicker -> less likely Drug A
    -0.30  * ckd                   +
    -0.25  * afib                  +
    -0.20  * insulin_use           +
    -0.15  * cardiomyopathy        +
    -0.10  * nephropathy           +
    -0.18  * comorbidity_index     +
    -0.20  * (region == "South")   +
     0.10  * sglt2i
  )
  dat$treatment <- rbinom(n, 1, plogis(ps_lp))

  dat <- dat |>
    dplyr::mutate(treatment_label = factor(treatment,
                                           levels = c(0, 1),
                                           labels = c("Drug B", "Drug A")))

  # ----------------------------------------------------------------------------
  # 3. Simulate the primary composite endpoint
  #    (HF hospitalization OR all-cause mortality) as a single time-to-event.
  #    Hazard is driven by genuine risk factors PLUS the treatment effect.
  #    Weibull baseline; lambda calibrated to a ~3.4% 1-year risk in the
  #    (reference) Drug B-like average patient.
  # ----------------------------------------------------------------------------
  cov_x <- dat |>
    dplyr::transmute(
      age_c               = (age - 65) / 10,
      bmi_c               = (bmi - 33) / 5,
      prior_hf_hosp,
      diuretic_use,
      nephropathy,
      insulin_use,
      pad,
      afib,
      cardiomyopathy,
      ckd,
      copd,
      dementia,
      comorbidity_index_c = comorbidity_index - 2,
      n_hospitalizations,
      treatment
    ) |>
    as.data.frame()

  # Log-hazard ratios for the outcome (treatment is the estimand of interest).
  betas <- c(
    age_c               = 0.45,
    bmi_c               = 0.08,
    prior_hf_hosp       = 0.90,
    diuretic_use        = 0.25,
    nephropathy         = 0.30,
    insulin_use         = 0.35,
    pad                 = 0.30,
    afib                = 0.40,
    cardiomyopathy      = 0.55,
    ckd                 = 0.50,
    copd                = 0.25,
    dementia            = 0.60,
    comorbidity_index_c = 0.20,
    n_hospitalizations  = 0.15,
    treatment           = true_log_hr
  )

  sim <- simsurv::simsurv(
    dist    = "weibull",
    lambdas = 1.8e-5,   # baseline scale (calibrated for ~3.4% 1-yr risk)
    gammas  = 1.15,     # mild increasing baseline hazard
    betas   = betas,
    x       = cov_x,
    maxt    = max_fu_days
  )
  # sim has columns: id, eventtime, status (status = 1 if event before maxt)

  # ----------------------------------------------------------------------------
  # 4. Treatment-independent censoring (disenrollment / discontinuation +
  #    45-day grace period). Combined with administrative censoring at max_fu_days.
  # ----------------------------------------------------------------------------
  cens_time <- rexp(n, rate = 1 / 400)   # treatment-independent dropout

  obs <- sim |>
    dplyr::mutate(
      cens_time  = cens_time,
      event_time = eventtime,
      fu_time    = pmin(event_time, cens_time, max_fu_days),
      # event observed only if it happens first AND within administrative window
      status     = as.integer(status == 1 & event_time <= cens_time &
                                event_time <= max_fu_days)
    ) |>
    dplyr::transmute(id, time = fu_time, status)

  # ----------------------------------------------------------------------------
  # 5. Return the in-memory analytic dataset (one row per patient)
  # ----------------------------------------------------------------------------
  dat |>
    dplyr::left_join(obs, by = "id") |>
    dplyr::relocate(id, treatment, treatment_label, time, status)
}

# ------------------------------------------------------------------------------
# When run directly (e.g., `Rscript 02_data_generation.R`), print a quick
# sanity-check summary. Nothing is written to disk.
# ------------------------------------------------------------------------------
if (sys.nframe() == 0) {
  cohort <- generate_cohort()
  cat("\n--- Simulated cohort summary ---\n")
  cat("N total:", nrow(cohort), "\n")
  print(table(Treatment = cohort$treatment_label))
  cat("\nCrude events by arm:\n")
  print(
    cohort |>
      dplyr::group_by(treatment_label) |>
      dplyr::summarise(
        n               = dplyr::n(),
        events          = sum(status),
        py              = sum(time) / 365.25,
        rate_per_1000py = round(1000 * events / py, 1),
        .groups         = "drop"
      )
  )
}
