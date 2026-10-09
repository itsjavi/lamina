---
id: TASK-57
title: Options bars for every other tool in familiar order
status: To Do
assignee: []
created_date: '2026-10-09 02:14'
labels: []
milestone: m-5
dependencies:
  - TASK-54
  - TASK-52
  - TASK-53
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: high
type: feature
ordinal: 57000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Each tool's bar orders and names its controls its own way: a Mode picker instead of selection icons, a Feather button that blurs the current selection, Size and Hardness as fields, a color swatch in the brush bar, This Layer / All Layers pickers, Apply and Cancel text buttons. docs/DESIGN.md lists each tool's bar in the order switchers expect.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every tool's bar shows the controls, order and names in docs/DESIGN.md, including its in-progress placeholders
- [ ] #2 Selection tools use the New, Add and Subtract icon buttons; Feather sets the feather for the next selection, while Select ▸ Modify ▸ Feather… still feathers an existing one; the Object Selection and Magic Wand bars include Select Subject
- [ ] #3 Painting tools share a brush picker pop-up holding Size and Hardness; Opacity, Flow, Smoothing and Strength are percent fields with a slider pop-up; the brush bar no longer shows a color swatch or the mask Black / White picker
- [ ] #4 Crop, Type and any edit in progress end with Cancel and Commit icon buttons; the Type bar splits font family and style and opens Properties ▸ Character for leading and tracking
- [ ] #5 The Hand and Zoom bars offer 100%, Fit Screen and Fill Screen, and the Zoom bar adds zoom in and out and Scrubby Zoom
- [ ] #6 Keyboard behavior (1–0 opacity, [ and ] size, Return and Escape) is unchanged and covered by tests
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->
