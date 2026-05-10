---
name: doview-image-retriever
description: Retrieve and faithfully reproduce DoView Planning handbook diagrams to accompany an outcomes-theory answer. Use after a doview-outcomes-answer response when the user asks to see the diagrams, requests the visual model, says "show me the picture/diagram/figure", or whenever an outcomes-theory answer would land better with the original tool diagrams visible. Reproduces Mermaid blocks from the local Markdown edition first (https://github.com/cgbarlow/doview-book), and falls back to the upstream PNG/image-file URLs from doviewplanning.org when a chapter's diagram does not translate cleanly to Mermaid. Faithful — never redraws, simplifies, paraphrases, or substitutes images or Mermaid blocks. Pair with doview-outcomes-answer, which sets up the seed list this skill consumes.
---

# DoView Diagram Retriever (Mermaid + PNG fallback)

> Faithful adaptation of *Prompt B — Outcomes Theory Book Image Retriever Prompt (v1.1.9)*
> from https://www.doviewplanning.org/bookai. Source content © Dr Paul W Duignan and
> DoViewPlanning.Org. Extended to retrieve **Mermaid blocks** as the primary representation
> (the source diagrams are available as Mermaid in the
> [doview-book](https://github.com/cgbarlow/doview-book) repo), with the upstream
> PNG/image-file rules preserved as a fallback.

## Medium adaptation note (added in this skill — not in the upstream prompt)

Prompt B was originally written to retrieve and embed PNG images from doviewplanning.org pages. In this skill's context, the same diagrams are available as Mermaid code blocks inside chapter `tool.md` files in https://github.com/cgbarlow/doview-book under `docs/md/Part X - …/Xnn - …/`. When the cited chapter has a Mermaid block, retrieve and reproduce the Mermaid block as the primary visual. When the chapter's `tool.md` notes "does not translate cleanly to Mermaid" (a small number of poster-style diagrams), fall back to the upstream PNG/image-file URL behaviour against the doviewplanning.org source page.

The Mermaid-first additions appear below as clearly-delimited subsections labelled **MERMAID-FIRST EXTENSION**. Everything outside those subsections is byte-identical to the upstream Prompt B v1.1.9.

---

Prompt B: Outcomes Theory Book Image Retriever Prompt (for use directly after Prompt A response has been generated)
Prompt B: Outcomes Theory Book Image Retriever Prompt
Version: 1.1.9
Use this page as the source page for retrieving relevant images from Dr Paul Duignan’s outcomes theory handbook and its linked tool pages:
https://doviewplanning.org/bookai
Use this prompt after Prompt A: Outcomes Theory Text Response Prompt has produced a response.
Look at the response immediately above and identify the full visible plain-text URLs in it.
First look for the heading:
Image-retrieval seed list for Prompt B
Use the URLs under that heading as the primary pages to inspect for relevant images.
If that heading is absent, use the full visible plain-text URLs in the response above.
Check only those URLs, and only the permitted outcomes theory handbook and tool pages from Dr Paul Duignan’s DoView Planning and Outcomes Theory Handbook:
https://doviewplanning.org/book
and the individual tool pages linked from that handbook, running from:
https://doviewplanning.org/a1doviewtool
through to:
https://doviewplanning.org/j7doviewtool
Do not use any other part of the DoView website. Do not use the rest of the internet. Do not use general knowledge.
TASK
Identify whether any directly relevant DoView Board, diagram, figure, image, or visual model appears on the permitted pages and is relevant to the answer immediately above.
The purpose of this prompt is to retrieve relevant source images faithfully. It is not to write a new outcomes theory answer.
IMAGE DISPLAY LIMITATION WARNING
Begin the response with this note:
This image-retrieval response attempts to display the most relevant original images from the permitted handbook and tool pages. Image display depends on the AI system’s technical ability to embed images from source URLs. Some relevant images may appear directly in the chat, while others may only be available as full visible plain-text image URLs.
IMAGE PRIORITISATION RULE
If many relevant images are found, do not try to include every possible image. Prioritise the most important images for understanding the previous outcomes theory answer.
Display or embed as many directly relevant original images as the AI system can reliably include, prioritising:
1. images from the most directly relevant tool pages;
2. images that are DoView Boards, diagrams, figures, or visual models rather than decorative images;
3. images that directly illustrate the main technical outcomes problem in the previous answer;
4. images that help explain the most important outcomes theory principle used in the previous answer.
If only some relevant images can be displayed, include the displayed images first, then list the remaining relevant image page URLs and image-file URLs in full visible plain text.
Do not invent, redraw, simplify, improve, or approximate any missing image.
MANDATORY IMAGE DISPLAY RULE
If a directly relevant image is found and an image-file URL is available, the AI system must attempt to display the original image in the response.
Do not merely provide a link to the image if the image-file URL is available.
For each image-file URL, include both:
1. The full visible plain-text image-file URL.
2. A markdown image embed line using the same image-file URL, in this exact format:
![Original image from the DoView Planning and Outcomes Theory Handbook](FULL_IMAGE_FILE_URL_HERE)
The image-file URL must remain visible in plain text immediately before the markdown image embed line.
If the AI system is capable of rendering markdown images, this should make the image appear in the response.
If the AI system cannot render markdown images, the markdown image embed line must still be included so the user can copy it into a system that can render it.

### MERMAID-FIRST EXTENSION — Mandatory Mermaid display rule (this skill only)

For each tool URL in the seed list, before falling back to PNG retrieval, check whether the corresponding chapter `tool.md` in https://github.com/cgbarlow/doview-book/tree/main/docs/md contains a Mermaid code block under a `## Diagram` heading. The mapping is by tool code:

- `https://doviewplanning.org/b16doviewtool` → look for the chapter folder whose code is `B16` under `docs/md/Part B - …/B16 - …/b16tool.md`.
- `https://doviewplanning.org/g02adoviewtool` → look for `docs/md/Part G - …/G02A - …/g02atool.md`.
- General pattern: `<letter><digits><optional-subletter>` from the URL maps to a chapter code zero-padded to two digits (e.g. `b1` → `B01`, `g25` → `G25`, `g2a` → `G02A`).

If the chapter `tool.md` contains a Mermaid block, reproduce the block faithfully in the response inside a fenced ```` ```mermaid ```` code block. This is the primary representation. The image-file URL (and the markdown image embed line) for the same tool may still be included for AI systems that can render the PNG, but the Mermaid block must be present first.

If the chapter `tool.md` does **not** contain a Mermaid block (it carries the note "*This page contains a visual that does not translate cleanly to Mermaid; described above.*"), fall back to the upstream PNG/image-file URL behaviour as written elsewhere in this prompt.

IMAGE FAITHFULNESS RULES
If a directly relevant image is found, reproduce it faithfully only by displaying, embedding, or copying the original image from the permitted source.
Do not redraw it from memory.
Do not simplify it.
Do not improve it.
Do not create a new substitute image.
Do not invent missing labels, arrows, boxes, colours, grouping, or layout.
Do not create a new diagram inspired by the source.
Do not use an image from outside the permitted handbook or tool pages.
If an image-file URL is available, do not state that the image cannot be reproduced unless the system has actually failed to display or embed it.
If the original image cannot be faithfully displayed or embedded, state exactly:
The relevant image was identified, but this AI system cannot faithfully display or embed the original image here.
Then provide:
1. The full visible plain-text URL of the page where the image appears.
2. The full visible plain-text URL of the image file, if available.
3. The markdown image embed line using the image-file URL, if available.

### MERMAID-FIRST EXTENSION — Mermaid faithfulness rules (this skill only)

The above IMAGE FAITHFULNESS RULES apply equally to Mermaid blocks retrieved from `docs/md/.../*tool.md`:

- Reproduce the Mermaid block byte-identical to the source `tool.md`.
- Do not rewrite, simplify, prettify, or paraphrase node labels.
- Do not change `flowchart LR` to `flowchart TD` (or vice versa) to fit chat width — copy the orientation as written.
- Do not strip surrounding prose. If the `tool.md` has explanatory prose under the `## Diagram` heading (e.g. NOW / FUTURE annotations), include that prose verbatim immediately after the Mermaid block.

OUTPUT FORMAT
Begin with this heading:
Relevant images from the DoView Planning and Outcomes Theory Handbook, Duignan, P. (2025),
https://doviewplanning.org/book
Then include the required image display limitation warning.
Then, for each relevant image, provide:
1. Image or diagram title/caption, if available.
2. Page URL: [full visible plain-text URL of the page where it appears]
3. Image file URL: [full visible plain-text URL of the image file itself, if available]
4. Original image:
![Original image from the DoView Planning and Outcomes Theory Handbook](FULL_IMAGE_FILE_URL_HERE)
5. Formal relevance note: [short formal note explaining why the image is relevant to the previous outcomes theory answer]

### MERMAID-FIRST EXTENSION — Output format additions (this skill only)

When a Mermaid block is being retrieved (the primary path for chapters that have one), the per-image block extends to:

1. Image or diagram title/caption, if available.
2. Page URL: [full visible plain-text URL of the page where it appears]
3. doview-book chapter URL: [full visible plain-text URL of the chapter `tool.md` in https://github.com/cgbarlow/doview-book/tree/main/docs/md/...]
4. Mermaid (primary):
   ```mermaid
   <verbatim Mermaid block from the chapter tool.md>
   ```
5. Image file URL: [full visible plain-text URL of the image file, if available — included for AI systems that can render PNG]
6. Original image:
   ![Original image from the DoView Planning and Outcomes Theory Handbook](FULL_IMAGE_FILE_URL_HERE)
7. Formal relevance note: [short formal note explaining why the diagram is relevant to the previous outcomes theory answer]

If no directly relevant image is found in the permitted handbook or tool pages, state exactly:
No directly relevant image was identified in the permitted handbook or tool pages.
RAW VISIBLE URL RULE — COPY-SAFE URLS FOR HUMANS
Every page URL and every image-file URL must be written as raw, visible, copy-safe plain text beginning with https://
The purpose of this rule is that a human must be able to copy the response into an email, document, report, or plain-text system and still see every URL.
Do not hide page URLs behind words.
Do not use reference-style links such as “[1]”.
Do not use footnotes.
Do not use source icons.
Do not use citation markers.
Do not use embedded hyperlinks for page URLs.
Do not write “see above”.
Do not write “see links above”.
Do not use shortened URLs.
Exception: markdown image syntax is required only for displaying the original image, and only after the image-file URL has already been written out in full visible plain text.
Correct image format:
Page URL:
https://doviewplanning.org/b16doviewtool
Image file URL:
https://images.squarespace-cdn.com/example/b16tool.png
Original image:
![Original image from the DoView Planning and Outcomes Theory Handbook](
https://images.squarespace-cdn.com/example/b16tool.png
)
Incorrect image formats:
Page URL: [Tool B16](
https://doviewplanning.org/b16doviewtool
)
Image: click here
Image file URL hidden behind linked text
See image above
See links above
Only use page URLs from:
https://doviewplanning.org/book
and the linked tool pages from:
https://doviewplanning.org/a1doviewtool
through to:
https://doviewplanning.org/j7doviewtool
Image-file URLs may come from the image files embedded on those permitted handbook or tool pages.
Do not use
https://doviewplanning.org/bookai
as the human-facing handbook reference. The human-facing handbook reference must use:
https://doviewplanning.org/book
REFERENCE
End with this full reference, with the URL written as raw visible plain text:
Duignan, P. (2025). DoView Planning and Outcomes Theory Handbook: 100+ Innovative, Integrated Tools for Solving Key Issues in Planning, Implementation, Contracting, Measurement, Evaluation and Reporting (for Humans and AI Agents).
DoViewPlanning.Org
.
https://doviewplanning.org/book
FINAL COMPLIANCE CHECK BEFORE ANSWERING
Before giving the image response, check and correct the response so that:
1. It is only about relevant images, diagrams, DoView Boards, figures, or visual models.
2. It begins with the required image display limitation warning.
3. Every image included comes only from the permitted handbook page or permitted linked tool pages.
4. No image has been invented, redrawn, simplified, improved, or reconstructed beyond what is visible in the permitted source.
5. The most relevant images are prioritised if many relevant images are found.
6. Every page URL is written out in full visible plain text beginning with https://
7. Every image-file URL, if available, is written out in full visible plain text beginning with https://
8. Every available image-file URL is followed by a markdown image embed line using that same full image-file URL.
9. The response does not merely provide image links when image-file URLs are available.
10. There are no reference links, no footnotes, no “[1]” style citations, no hidden page URLs, and no “see above” wording.
11. Before finalising the response, actively scan it for hidden links. If page URLs or image-file URLs are hidden behind words, rewrite them as raw visible plain text.
12. The response ends with the full handbook reference and
https://doviewplanning.org/book
.

### MERMAID-FIRST EXTENSION — Compliance check additions (this skill only)

Additional checks (this skill only):

13. For every tool URL in the seed list that maps to a chapter `tool.md` containing a Mermaid block, a verbatim Mermaid block is included in the response **before** any image-file URL for the same tool.
14. Every Mermaid block is byte-identical to the source `tool.md`. Node labels, orientation, and surrounding prose are not paraphrased, prettified, or reordered.
15. For chapters whose `tool.md` carries the "does not translate cleanly to Mermaid" note, the response falls back to the upstream PNG/image-file behaviour — no synthetic Mermaid block is invented.
