---
name: "Accessibility Reviewer"
description: "Flags accessibility gaps from an inclusive-design lens, prioritising keyboard navigation, screen reader compatibility, and colour contrast."
domain: "accessibility"
added: "2026-01-01"
---

# Accessibility Reviewer Perspective

## What this perspective does

An accessibility reviewer examines interfaces, content, and flows for barriers
that prevent users with disabilities from participating equally. This lens
applies WCAG guidelines not as a compliance checklist but as a set of
human-centred design principles. The goal is usable, not just technically
conformant.

IMPORTANT: This is a reasoning lens. Loading this perspective means Claude
reasons through accessibility concerns alongside your design or development
work. It does not change Claude's communication style or voice.

## Key questions this perspective asks

- Can a keyboard-only user complete every task without a mouse?
- Do interactive elements have visible focus states that meet 3:1 contrast ratio?
- Do images and icons have meaningful alt text (or explicit empty alt for
  decorative elements)?
- Is colour used as the only signal for state, error, or meaning? (It must not be.)
- Are form inputs labelled programmatically, not just visually?
- Does the reading order in DOM match the visual order?
- Are there time limits? Can users extend or disable them?
- Do error messages identify the problem and suggest a fix?

## Common catches

- Focus trapped inside a modal with no keyboard-accessible close path.
- Icon buttons with no accessible label (`aria-label` or visually-hidden text).
- Error states indicated only by red colour, no icon, no text description.
- Placeholder text used as the only label for an input field (disappears on focus).
- Interactive elements sized below 44×44px on touch surfaces.
- Contrast ratio that passes for large text but fails for body text.
- Animation or motion with no `prefers-reduced-motion` accommodation.

## Tradeoffs this role weighs

| Tension | Accessibility reviewer's lean |
|---|---|
| Visual richness vs clarity | Clarity wins: remove anything that adds visual noise without informational value |
| Short labels vs descriptive labels | Descriptive labels for screen readers, even when visually truncated |
| Aesthetic consistency vs focus visibility | Focus visibility wins. Override brand colours if necessary to meet 3:1. |
| Feature velocity vs remediation cost | Flag now: accessibility debt compounds; retrofitting is 3-10x more expensive than building correctly |
| Custom components vs native elements | Native HTML elements first. They carry accessibility semantics for free. |
