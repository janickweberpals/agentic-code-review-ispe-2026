<img src="images/icpe26_logo.jpg" data-fig-align="center" />

**Unlocking the Power of Pharmacoepidemiology to Improve Patient Health**
>Allianz Milan Convention Center, Milan, Italy
>August 29–September 2, 2026

---

## Agentic Code Review and Validation

**An Introduction to Agentic Coding Assistants**
*ISPE 2026 Annual Conference — Educational Workshop*

This repository supports an educational workshop on using agentic coding assistants for code review and validation in pharmacoepidemiology and drug safety research. It covers the role of code review as a pillar of transparent and reproducible research, introduces AI-powered coding agents (Claude Code, GitHub Copilot), and demonstrates how these tools can be integrated into pull request workflows to systematically review analytic code against pre-specified study protocols.

---

## Repository Structure

```
.
├── code_review_presentation.qmd   # Main RevealJS slide deck (Quarto)
├── _render_presentation.R         # Post-render script: renders & copies slide deck to _book/
├── custom.scss                    # Custom presentation theme
├── references.bib                 # Bibliography
├── mock-study/                    # Example pharmacoepidemiology study
│   ├── 01_csp.qmd                 # Clinical study protocol
│   ├── 02_data_generation.R       # Synthetic data generation
│   └── 03_primary_endpoint_analysis.qmd  # Primary analysis script
├── images/                        # Figures and diagrams used in slides
├── .github/workflows/publish.yml  # CI/CD: render & deploy to GitHub Pages
├── .claude/                       # Claude Code configuration
│   ├── CLAUDE.md                  # Project-level AI assistant instructions
│   └── agents/
│       └── code-reviewer.md       # Custom /code-reviewer agent definition
└── renv.lock                      # R package environment (reproducible)
```

---

## Key Topics

- **Why code review matters** — consequences of coding errors in pharmacoepidemiology research
- **Pull request workflow** — using GitHub PRs as a structured peer-review mechanism for code
- **AI coding agents** — architecture of LLM-based agents (model + harness) and how they differ from traditional coding assistants
- **Claude Code** — agentic CLI tool for reading codebases, editing files, running commands, and integrating with development workflows
- **GitHub Copilot** — AI coding assistant integrated into IDEs and GitHub
- **Custom agents** — how to define project-specific review agents using `.claude/agents/`
- **Mock study** — hands-on example of agentic code review against a clinical study protocol

---

## Requirements

- [R](https://www.r-project.org/) (≥ 4.5)
- [Quarto](https://quarto.org/) (≥ 1.5)
- R packages managed via [`renv`](https://rstudio.github.io/renv/) — restore with:

```r
renv::restore()
```

- [Claude Code](https://claude.ai/code) (for agentic review demonstrations)

---

## Rendering

```bash
quarto render
```

This builds the full site — book chapters and the embedded RevealJS presentation — in one step. The post-render script (`_render_presentation.R`) handles rendering the slide deck and placing it in `_book/` automatically.

The site is also built and deployed to GitHub Pages automatically via GitHub Actions on every push to `main`.

---

## License

This repository is licensed under the terms of the [LICENSE](LICENSE) file included in this repository.

---

*Presented by Janick Weberpals, RPh, PhD*
