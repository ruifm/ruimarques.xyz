---
title: 'Fewer Engineers, Harder Problems'
date: 2026-04-11
description: 'How AI can reduce the number of software engineers and increase the need for verification, judgment, and training.'
draft: false
---

AI will not end software engineering. I think it will make the profession smaller.

For much of the last twenty years, companies needed more software than their teams could build. The time needed to write code was a main constraint. AI tools reduce that time when a requirement is clear and the implementation follows a known pattern.

Cheaper software can also create new demand. We may build systems that were not worth their cost before. Nobody knows whether that demand will offset the productivity gain. Still, we should not assume that software employment will continue on its old path.

If the profession does become smaller, the work left to people will be harder. More of the job will consist of deciding what to build, understanding how a change affects a system, proving that it works, and accepting responsibility when it does not.

## The Verification Problem

The usual debate puts frontend and CRUD work in the exposed group, and compilers and kernels in the safe group. This view is too simple.

A better test is to ask what happens when the tool is wrong.

If nine out of ten generated changes are correct, the tool can be valuable when each change is easy to test and cheap to reverse. It is less useful when one error can corrupt data, expose a secret, or fail only under rare conditions. In that case, the engineer must know enough to find the tenth error. The cost of review can exceed the time saved during implementation.

The test applies to tasks, not job titles. A compiler pass can have a clear specification and an excellent test suite. A web endpoint can sit on a security boundary and handle money. The important factors are the cost of failure, the strength of the tests, and the amount of system knowledge needed to review the result.

Current productivity studies show why broad claims fail. In [three field experiments with 4,867 developers](https://doi.org/10.2139/ssrn.4945566), access to a code-completion tool increased completed tasks by 26% in aggregate. In [a different experiment](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/), 16 experienced open-source developers who used early-2025 tools took 19% longer to complete work in mature repositories that they knew well. METR's [later data](https://metr.org/blog/2026-02-24-uplift-update/) suggested a gain, but the researchers said selection effects made the estimate unreliable.

Both results can be valid. The studies measured different tools, people, and work. A productivity estimate means little until we define the task and the quality standard.

Generated code can feel productive before it saves time. In [Stack Overflow's 2025 survey](https://survey.stackoverflow.co/2025/ai), 66% of respondents reported frustration with answers that were almost right, and 45% said that debugging generated code took more time. Typing is faster. Verification is still work.

## The Apprenticeship Gap

A [Stanford study of payroll data through June 2026](https://digitaleconomy.stanford.edu/publication/canaries-in-the-coal-mine-six-facts-about-the-recent-employment-effects-of-artificial-intelligence/) found no broad collapse in employment. It found that employment among workers aged 22 to 25 in AI-exposed occupations was 19% below where it would have been if it had kept pace with less-exposed workers. Most of the gap came from reduced hiring rather than more separations. The authors describe these results as early evidence, not proof that AI caused the change.

AI offers one possible explanation. If an experienced engineer with good tools can absorb tasks that might have gone to a junior, the next junior hire is easy to delay. This can make sense for one company. If many companies make the same decision, the industry loses its training pipeline.

Senior engineers do not appear after five years have passed. They become senior by working on real systems, making mistakes with limited impact, receiving review, and taking on more responsibility. A company that stops hiring juniors can reduce its current costs while it weakens the future supply of senior staff.

Advice to new engineers is therefore only half an answer. Employers control access to production systems, review, and paid experience. They must treat training as an investment, even when giving the work to an AI-assisted senior costs less today.

## What Still Matters

There is no safe list of technologies. AI tools will improve in compilers, kernels, security, and embedded systems too. Depth and judgment offer more protection than a job title.

For a new engineer, this means learning one real system in depth. It can be a compiler, database, network service, browser, build system, or large product. The specific choice matters less than learning its constraints: compatibility, failure modes, performance, security, deployment, and the reasons behind its design.

Open-source work remains useful evidence of that depth. A public contribution can show more than the final patch. It can show how you chose the problem, discussed the design, wrote tests, answered review comments, and maintained the result. AI can help with each step, but the author is still responsible for the work.

Use AI, but do not make it the only way you can work. You should be able to explain every change that you submit, name its main failure modes, and decide how to test it. Fast output without that control is a liability.

Companies also need a clear training process. Give junior engineers small tasks that matter. Review both their decisions and their diffs. Use AI to shorten feedback loops, but keep people involved in diagnosis, design, and incident response. A larger stream of generated code cannot replace experience.

## A Smaller Profession?

I still expect fewer software engineers to produce more software. I do not expect a clean split between automated jobs and protected jobs. Every part of the field will use these tools. The difference will be how much human judgment is needed to specify, verify, and own the result.

This could produce a profession with fewer entry points and a higher bar. New demand could also keep total employment high. It is too early for the evidence to settle that question.

The apprenticeship problem does not need to wait for an answer. Engineers should build depth and learn how to verify their work. Employers should keep creating paths from junior work to senior responsibility. If they do not, the industry will learn too late that generating code and developing engineers are separate problems.
