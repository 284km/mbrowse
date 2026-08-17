# Open questions

Things this repository knows it does not know, with what has already been tried.

The point of the file is the second half. Several of these have an obvious repair that has been made
and measured and turned out to be a net loss; without somewhere to write that down, the obvious
repair gets made again, costs the same documents again, and gets reverted again. A question with a
rejected answer attached is worth more than a question.

Each entry says what the failure is, what was tried, and what would settle it. Where a gate can see
the question, the count is given; where it cannot, that is the finding.

---

## Q-1. An inline box's height, when a child sticks out of it

**4 documents** — `block-in-inline-nested-001`, `-002`, `-002-ref`, `block-in-inline-append-002-ref`.

`block-in-inline-nested-002-ref` wants a `<span>` with no border of its own to be ten pixels taller
than its line, because the empty `<span>` inside it has a 5px border. Every simple reading of that is
"an inline box covers its descendants".

**Tried twice, rejected twice.** Unioning an inline's box with its descendants' cost two documents
before the content-area rule was right, and one after — gaining none either time. And
`block-in-inline-append-002-nosplit-ref` says plainly that it cannot be a union: there, a `.outer`
with a 4px border extends *beyond* the `.outermost` with a 2px border that contains it. A box that
contained its descendants could not produce that.

So the two documents disagree under every rule stated so far. What the browser reports is the union
of an element's own FRAGMENTS; what makes that fragment taller in the first case is something else.

**What would settle it:** `getClientRects` on both documents, read side by side. A union does not say
what it is a union of, and that is exactly the question.

## Q-2. `display: inline-table` needs three pieces at once

**2 documents** — `inline-table-valign-001`, `-001-ref`.

`is_table` asks for the string `table` exactly, so an inline-table is laid out as an ordinary block
and none of the row machinery runs.

**Tried, measured, reverted — twice.** Admitting it alone costs a document and gains none. Adding the
anonymous row and row-group boxes as well (a group or row with an empty tag, laid out like any other
and not reported — which is why the box sequence never asked for them and the geometry always did)
puts the table and the cell exactly where the browser does and leaves everything after them five
pixels low, still a net loss of one.

The five pixels are the third piece: **an inline-table's baseline is the baseline of its FIRST ROW**,
not its bottom margin edge. Sitting it on its bottom edge puts the strut's descent below a baseline
it never had.

**What would settle it:** all three at once. Two of the three are worth less than none.

## Q-3. Sub-pixel accumulation along a line of inline-blocks

**4 documents** — `inlines-004`, `inlines-005`, `inline-block-003`, `inline-block-005`, off by one to
three pixels each.

An inline-block's advance on the line goes through its border-box width, which is a rounded whole
number. The browser keeps the fraction. So a line of several of them drifts by up to half a pixel
each, and the drift shows up as one pixel somewhere along the line.

This is a limit of the integer model rather than a missing rule. The cursor already counts in
`pixels x units-per-em` so that text at mixed sizes adds up exactly; the same treatment would have to
reach the shrink-to-fit width of a box, which is computed in pixels by `_block` because that is what
a box's width IS.

**What would settle it:** deciding whether a box can have a fractional width internally. That is a
change to what `box` means, not to an expression.

## Q-4. A branch no font here can exercise

`Font._points` handles a contour that begins on an off-curve point — the start is then the last point
if that one is on-curve, and otherwise the midpoint of the last and the first.

**No glyph in the vendored font does this.** Not one of its 3,748, checked directly. Poisoning the
branch changes nothing, which is how that was found: the segments gate stayed green with the rule
removed.

So the branch is written and is verified by nothing here. It is kept because the format allows it and
another font will use it.

**What would settle it:** a second font that uses the construction, or a synthesised one. Neither is
vendored, and vendoring a font for one branch is a real cost that has not been paid.

## Q-5. Ligatures, and the 116 characters in the wrong place

**116 documents** — `glyphpos_check.sh` passes 112 of 228 where the box gate passes 218. That gap is
the finding: 106 documents have every element box exactly where the browser puts it and at least one
character somewhere else.

Two causes, from the diffs:

  - **Ligatures.** The browser substitutes `fi` with a single glyph through GSUB, so its two
    characters share one rect and divide it differently. Nothing here does GSUB. This is a missing
    feature rather than a wrong number — the pair occupies the same total width either way — and
    implementing it means reading GSUB the way GPOS is already read for kerning.
  - **Single-pixel drift** along a long line, which is [Q-3](#q-3-sub-pixel-accumulation-along-a-line-of-inline-blocks)
    seen one character at a time instead of once at the end of a span.

**What would settle it:** GSUB for the first; a decision about fractional box widths for the second.
They are independent.

## Q-6. Painting — done, and what it costs

Closed. `src/paint.mere` turns boxes and glyphs into pixels and `reftest_check.sh` compares 109 pairs
the WPT authors named: **61 pass**. The pipeline runs end to end — bytes, characters, tokens, a DOM,
styles, boxes, ink.

Two things it leaves open.

**It takes about ninety minutes**, because painting asks the outline whether it covers each pixel of
each glyph's box and there are 218 pages of them. That is the honest cost of the only gate that draws;
it runs last and is the one to skip while iterating.

**Where the time is NOT**: reading the curves. Caching each distinct glyph's outline per page — forty
shapes parsed once instead of five hundred times — was written, timed, and reverted: 29 seconds either
way on the same document, identical output. The cost is entirely the point-in-path test per pixel.

So making it quick means a scanline rasteriser: solve each row's crossings once, sort them, fill the
spans between. Roughly the width of a glyph fewer winding computations. Not written, because nothing
needs the gate to be quick yet and the version here is the one the raster gate already checks exactly.

**Painting order is document order**, so later boxes cover earlier ones. That is right for everything
without `z-index` and this corpus has not yet said otherwise; when it does, the answer is stacking
contexts and not a bigger sort.

The 48 failures are the layout failures seen from the other side. A test and its reference that lay
out to different heights are two different pictures, and a reftest cannot say which of the two is
wrong — that is what the other gates are for. It says that two pages disagree.

## Q-7. How long the layout gate takes

The engine is superlinear in the number of sibling inline elements: 40 spans in a paragraph take 1.5
seconds and 80 take 17. `inlines-004` has 130 of them.

Measured against an earlier commit — 1542ms then, 1594ms now for 40 spans — so it is not something
the recent work introduced, and it has not been chased.

**A warning about measuring it:** a wall-clock number from `layout_check.sh` is not evidence on its
own. The same code on the same corpus has taken 9 minutes and 2.5 hours in one sitting, at load
averages of 1 and of 21.


## Q-8 — two JPEG header readings this oracle cannot tell apart

`scripts/jpeg_check.sh` was poisoned eight ways and bites on six. The other two are not gaps in the
corpus, they are inputs that do not exist here:

- **The DQT precision bit.** A 16-bit quantisation table needs 12-bit samples, and this libjpeg was
  not built with them. A reader that assumes every table is 8-bit is indistinguishable from a correct
  one on every file Pillow can write.
- **Stopping at the scan.** Baseline entropy data is byte-stuffed, so the only `FF` pairs after SOS are
  `FF 00` and the restart markers. No well-formed baseline file contains anything a header walker could
  mistake for a header, so "stop at SOS" and "keep walking" agree on all of them. It matters for
  damaged input and for progressive JPEG.

Also unreached: several quantisation tables inside ONE DQT segment. Legal, and libjpeg does not do it.

**What would settle it** is a hand-written JPEG — bytes assembled directly rather than through an
encoder — but a file this repository writes is not an oracle for a reader this repository wrote, so it
would have to come with something independent that agrees it is what it claims to be. Until then the
honest form is this note and not a passing test.

## Q-9 — the JPEG AC path and the inverse DCT — CLOSED

Closed by implementing libjpeg's integer transform rather than a transform, which is what the note
below said would close it. Both detailed images decode bit-identically, 2507 and 1407 non-zero AC
coefficients between them, and the sixteen-zeroes escape and the run-length pairs are now executed.

The reasoning is kept because it is the general shape of this problem and it comes up again wherever
an output is an approximation: **an exact comparison is only available against a named implementation,
and a tolerance is worse than a narrower claim** — it hides a real error behind a difference of method
and cannot tell the two apart afterwards. The narrower claim, said out loud, is "the same as libjpeg".

What remains genuinely unimplemented and is NOT a gate hole: progressive JPEG (SOF2), arithmetic
coding, and 12-bit samples. None of them is baseline.
That is worth having before the transform is worth writing.

## Q-10 — `max-width` is not implemented

`test/data/img/img-max-width.html` is the one document in `scripts/img_check.sh` that fails, and it
fails because `max-width` does not exist in this engine rather than because images are wrong. The
browser gives a 48-wide image with `max-width: 20px` a box of 20 by 13 — the 13 comes from the 20 by
the intrinsic ratio, so the constraint is applied BEFORE the ratio, not after.

It is not an image property. It applies to every box, so implementing it means a new property through
the cascade and a new step in every width calculation, which is a change to the 228 documents next
door and not to the 21 here. The document stays and the count is pinned at 20 so that implementing it
makes this gate fail and say so.

## Q-11 — a stated ratio under `border-box`

When the page states one dimension of an image and `box-sizing: border-box`, the other dimension is
derived from the intrinsic ratio — and CSS derives ratios against the CONTENT box, while the stated
one is a border box. `src/layout.mere` treats both as being in the same terms, which is right in every
document here and wrong in principle.

No document in the corpus has that shape, so this is written down rather than guessed at. Adding one
is cheap and is the right next step if anything in this area is touched.

## Q-12 — a scaled image has no exact answer

`scripts/imgpaint_check.sh` compares painted pixels against a browser's screenshot exactly, and it can
only do that for images drawn at their NATURAL size. An image drawn larger or smaller has to be
resampled, every engine resamples differently, and the standard does not say how — the same shape as
the JPEG upsampler and the inverse transform.

`src/paint.mere` repeats the nearest pixel, which is the placeholder rather than the decision. The
options are the ones taken elsewhere in this repository: match a named implementation and compare
exactly, or ask a weaker question that has one answer. Neither has been done, so the documents that
scale are not in that gate and the nearest-pixel code is not checked by anything.

## Q-13 — no box draws a border — CLOSED

`src/paint.mere` now draws one, as four bands rather than as a filled border box with the padding box
painted over it: the second version paints over the element's own background, which was put down first
and is a different colour. Four bands and not one inset because the widths ARE four, and `border-bottom`
alone already makes them differ.

The border colour is new in the cascade. Its initial value is `currentColor`, so it falls back to the
element's own `color` rather than to black — which is why `border: 3px solid` with no colour named
comes out the colour of the text. ONE colour and not four: CSS allows a colour per side, no document
here uses one, and four fields that are always equal are three chances to set the wrong one.

**Why this was worth finding before the reftest failures were analysed**, which is what the earlier
version of this note said: nothing in this engine drew a border, and nothing had said so. The only
other thing that looks at ink is a reftest, and a reftest comparing two pages that both omit the border
agrees with itself. Attributing the 48 reftest failures to layout while this was true would have been
attributing them to the wrong thing.
