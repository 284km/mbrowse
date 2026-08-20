# Open questions

Things this repository knows it does not know, with what has already been tried.

The point of the file is the second half. Several of these have an obvious repair that has been made
and measured and turned out to be a net loss; without somewhere to write that down, the obvious
repair gets made again, costs the same documents again, and gets reverted again. A question with a
rejected answer attached is worth more than a question.

Each entry says what the failure is, what was tried, and what would settle it. Where a gate can see
the question, the count is given; where it cannot, that is the finding.

**The counts here are checked.** They were not, and `Q-6` spent a day saying 61 of 109 with 48
failures while the gate was pinned at 71 of 76 — a number written twice, with only one of the copies
compared against anything. `scripts/questions_check.sh` runs three kinds of line:

    - **Number:** `71` = `<command printing the current value>`
    - **Reproduces when:** `<command exiting 0 while the symptom is present>`
    - **Documents:** `a.html` `b.html` in `LAYOUT_LIST`

A literal that disagrees with its command is stale in either direction — a count that has gone up
looks like progress and is the same defect. A symptom that stops reproducing, or a document that
starts passing, is a retire candidate. An entry with none of the three lines is counted and named,
so that "nothing here can be machine-checked" is a number rather than a silence.

---

## Q-1. An inline box's height, when a child sticks out of it

**4 documents** — `block-in-inline-nested-001`, `-002`, `-002-ref`, `block-in-inline-append-002-ref`.

- **Documents:** `block-in-inline-nested-001.html` `block-in-inline-nested-002.html` `block-in-inline-nested-002-ref.html` `block-in-inline-append-002-ref.html` in `LAYOUT_LIST`

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

- **Documents:** `inline-table-valign-001.html` `inline-table-valign-001-ref.html` in `LAYOUT_LIST`

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

- **Documents:** `inlines-004.html` `inlines-005.html` `inline-block-003.html` `inline-block-005.html` in `LAYOUT_LIST`

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

- **Number:** `112` = `sed -n 's/.*EXPECT_PASS:-\([0-9]*\).*/\1/p' scripts/glyphpos_check.sh`
- **Number:** `218` = `sed -n 's/.*EXPECT_PASS:-\([0-9]*\).*/\1/p' scripts/layout_check.sh`
- **Number:** `228` = `ls test/data/layout/*.glyphs | wc -l`
- **Number:** `116` = `echo $(( $(ls test/data/layout/*.glyphs | wc -l) - $(sed -n 's/.*EXPECT_PASS:-\([0-9]*\).*/\1/p' scripts/glyphpos_check.sh) ))`
- **Number:** `106` = `echo $(( $(ls test/data/layout/*.glyphs | wc -l) - $(sed -n 's/.*EXPECT_PASS:-\([0-9]*\).*/\1/p' scripts/glyphpos_check.sh) - $(ls test/data/layout/*.expected | wc -l) + $(sed -n 's/.*EXPECT_PASS:-\([0-9]*\).*/\1/p' scripts/layout_check.sh) ))`

The last of those is the surplus of character failures over box failures, and it reads as "106
documents" only while every box failure is also a character failure. **Measured rather than assumed**
— all ten documents in the box gate's failing list were run through the character gate and all ten
fail it too, so the surplus is 116 - 10. It is not gated, because doing so means running both slow
gates and intersecting their lists; if the two sets ever come apart, the arithmetic above will still
print 106 and it will have stopped meaning that.

Two causes, from the diffs:

  - **Ligatures.** The browser substitutes `fi` with a single glyph through GSUB, so its two
    characters share one rect and divide it differently. Nothing here does GSUB. This is a missing
    feature rather than a wrong number — the pair occupies the same total width either way — and
    implementing it means reading GSUB the way GPOS is already read for kerning.
  - **Single-pixel drift** along a long line, which is [Q-3](#q-3-sub-pixel-accumulation-along-a-line-of-inline-blocks)
    seen one character at a time instead of once at the end of a span.

**What would settle it:** GSUB for the first; a decision about fractional box widths for the second.
They are independent.

## Q-6. Painting costs an hour, and the time is not where it looks

`src/paint.mere` turns boxes and glyphs into pixels and `reftest_check.sh` compares them. The
pipeline runs end to end — bytes, characters, tokens, a DOM, styles, boxes, ink. What is open here is
the cost of asking.

- **Number:** `109` = `grep -cE '^(SAME|DIFF)' test/data/layout/reftest.browser`
- **Number:** `33` = `grep -c '^DIFF' test/data/layout/reftest.browser`
- **Number:** `76` = `grep -c '^SAME' test/data/layout/reftest.browser`
- **Number:** `71` = `sed -n 's/.*EXPECT_PASS:-\([0-9]*\).*/\1/p' scripts/reftest_check.sh`

**71 of 76 pass, and each of the 5 that fail has a side that already fails the layout gate.** The
denominator is 76 and not the 109 pairs the suite names: the browser renders 33 of them differently
itself, so those were never pairs. See the head of `reftest_check.sh` for how that was measured.

**This entry is why the counts in this file are now checked at all.** It said 61 of 109 with 48
failures for a day after the gate was pinned at 71 of 76 — the gate's number is compared against
reality on every run and the prose was compared against nothing, so the copy that drifted was the
copy nobody could see drift.

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

The 5 remaining failures are layout failures seen from the other side. A test and its reference that
lay out to different heights are two different pictures, and a reftest cannot say which of the two is
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

- **Number:** `20` = `sed -n 's/.*EXPECT_GEO:-\([0-9]*\).*/\1/p' scripts/img_check.sh`
- **Number:** `21` = `sed -n 's/.*EXPECT_SEQ:-\([0-9]*\).*/\1/p' scripts/img_check.sh`
- **Reproduces when:** `! grep -qih 'max-width' $IN`
- **Over:** `src/layout.mere src/style.mere`
- **Poisoned by adding:** `| "max-width" -> Some (parse_length v)`

## Q-11 — a stated ratio under `border-box`

When the page states one dimension of an image and `box-sizing: border-box`, the other dimension is
derived from the intrinsic ratio — and CSS derives ratios against the CONTENT box, while the stated
one is a border box. `src/layout.mere` treats both as being in the same terms, which is right in every
document here and wrong in principle.

No document in the corpus has that shape, so this is written down rather than guessed at. Adding one
is cheap and is the right next step if anything in this area is touched.

- **Reproduces when:** `! awk '/box-sizing:border-box/{w=/width:/;h=/height:/; if(w!=h) found=1} END{exit !found}' $IN`
- **Over:** `test/data/img/*.html`
- **Poisoned by adding:** `<style>img{box-sizing:border-box;width:60px}</style>`

The first version of that check asked whether any document uses `box-sizing` at all, and two do —
so it reported this question as retired on its first run. They state BOTH dimensions or NEITHER,
and the shape here is exactly one: the ratio has to be used for the disagreement to show. One
expression, two questions, and the wrong one is the easy one to write.

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

## Q-14 — document order is not painting order — CLOSED

`src/paint.mere` walks the box list in CSS 2.1 Appendix E's order: every block-level background and
border, then every float's, then one pass in tree order over the rest — each inline-level box's
background and border, and every box's ink, interleaved.

Two things had to be right and only one of them was obvious.

**The layer INHERITS.** Appendix E's step 7 is not "inline-level boxes", it is everything inside one: a
`display: block` box inside an inline-block paints with the inline-level content, so a later block
cannot cover it. Computing the layer from the element's own display gets that backwards, which is why
it is resolved in the cascade — inheritance is the mechanism, and the cascade is where inheritance is.

**The backgrounds and the ink interleave.** All inline-level backgrounds and then all the ink is a
different picture: an inline-block's red text lands on top of the green background of an inline that
comes after it, where the browser has the green covering both. Step 7 is per box — its background, its
border, its text — not per kind of thing. That one was found by measuring, not by reading.

**And one of the six was not paint order at all.** An inline box's `background: green` painted nothing,
because the inline box was constructed with no background, no border and the block-level layer. A
missing feature can look exactly like a wrong order when only one of two overlapping boxes is ever
drawn. Painting them cost 10 reftest pairs, all of them Q-15 — see below.

## Q-15 — an inline box split by a block gets its border split too — CLOSED

A box per fragment: anonymous, at the fragment's own y, as tall as its line plus both horizontal edges,
the start edge only on the first fragment and the end edge only on the last, placed from the right in a
right-to-left context. All fourteen pairs pass. The element's own box is still the union and still
carries no border, so nothing is drawn twice.

**It closed in four steps and three of them were the same mistake in different clothes.**

The fragment's width was `content OR edge` where it is `content PLUS edge`. Then the fragment's position
ignored the direction while its edges already honoured it. Then the fragment's CONTENT needed moving
right by the start edge too — the same fact as the width, with a second consequence that had not been
acted on: the inline pass is handed the piece's children and not the element, so it lays them out from
zero, and both the box's size and the content's position have to make that up.

**And a reading taken by a shortcut was worse than no reading.** A browser screenshot said the border
band was 29 pixels wide for both sides of a pair; taken with the vendored font injected it says 33, and
the side the first number implicated had been right all along. The tell was available both times it
happened in this arc — a value that should have differed did not.

**What settled which side was wrong** was not the reftest, which cannot say, and not a screenshot, which
cannot be compared for glyphs. It was the character-position gate: the browser puts the first glyph at
x=10 and this put it at 8. A reftest says two pages disagree; the gates with an outside oracle say which
one is lying.

## Q-16 — `tcp_connect` tries one address and stops

The first thing A9 needed was a socket, and the first thing the socket did was fail against
`localhost`.

`getaddrinfo` returns a LIST, ordered by the platform's preference. mere's `tcp_connect` takes
`res->ai_family` and `res->ai_addr` from the head of it and returns -1 if that one does not connect;
it never walks `ai_next`. On this machine `localhost` resolves to `::1` first, so a server bound to
`127.0.0.1` is unreachable by name while `curl` — which falls through to the next address — reaches
it over the same resolution.

This is not a loopback curiosity. It is the ordinary case for the real web: a host with an AAAA
record on a network with no working IPv6 route resolves fine, answers on IPv4, and cannot be
connected to from here. Every dogfood before this one either dialled a literal address or a name
that happens to resolve IPv4-first, which is why a socket layer that has been in use since v0.1.91
had never been asked this.

- **Number:** `9` = `sed -n 's/.*EXPECT_PASS:-\([0-9]*\).*/\1/p' scripts/fetch_check.sh`

**The gate asserts the current behaviour rather than describing it.** `scripts/fetch_check.sh`
fetches over `127.0.0.1` — the certificate carries `IP:127.0.0.1` as well as `DNS:localhost`, so
verification is unaffected and the difference is purely the connect — and its last case requires the
`localhost` spelling to come back `ERR connect failed`. When `tcp_connect` learns to walk the list,
that case fails and says the assertion is stale, which is the only way a note like this one closes.

**What would settle it:** upstream, a loop — try each `ai_next` in turn and return the first that
connects, which is what every client library does and what the standard call is shaped for. It is
about six lines. It is not done here because a fix belongs with a version number, a changelog entry
and a parity case in the repository that owns the runtime, and `mere`'s version is currently
inconsistent with itself: `lib/version.ml` says `0.1.283` while nine source comments and the last
commit message say `v0.1.284`. Cutting a release on top of that would compound it.

## Q-17 — a unit this engine does not know is treated as pixels

The first real page A9 fetched named its widths in `vw` and its margins in `vh`, and the answers came
back plausible and wrong. `example.com` asks for `width: 60vw` on a body in an 800-pixel viewport;
the browser gives it 480 and this gives it **60**, because `Style.px_at` ends its unit table with
`else 1.0` — an unrecognised unit is scaled as though it were `px`.

**The standard's answer is not "guess", it is "drop".** A declaration whose value cannot be parsed is
invalid and is ignored, so `width: 60vw` in an engine without viewport units should leave `width` at
`auto` — and `auto` on a block is the containing block's width, which is 800 and much closer to 480
than 60 is. **The approximation is further from right than the refusal would have been**, and it
arrives wearing the face of an answer: 60 is a number, it is in range, and nothing about it says a
unit went unread.

This is the general shape and it is worth the entry on its own: an absent distinction filled in with
a plausible default is harder to find than a missing feature, because a missing feature announces
itself and a wrong default does not. Every gate in this repository was written against documents that
use `px` and `em`.

- **Reproduces when:** `! grep -qw 'vw' $IN`
- **Over:** `src/style.mere`
- **Poisoned by adding:** `else if unit == "vw" then vw_scale`

**What would settle it, in the order the cost says:**

1. **Make an unknown unit invalid rather than one pixel.** `px_at` returns an int and has no way to
   say "no value", which is why the fallback exists at all — the sentinel has to reach the cascade so
   the declaration can be dropped. This is the correctness fix and it is independent of implementing
   anything.
2. **Then viewport units**, which need the viewport threaded to the cascade; it currently is not,
   because nothing before now asked for a length that depends on it.

Both are visible in `scripts/northstar_check.sh`, whose geometry number for this page is pinned at 0
of 7. It is pinned rather than skipped so that either fix makes the gate say the answers moved.

## Q-18 — this engine had never been compiled — CLOSED

A9's measurement report has to be of a binary: `now_ms` has no interpreter mock and says so rather
than returning a plausible zero, which is the right refusal and is also what surfaced this. The
program compiled — `mere -c` exited 0 with nothing on stderr — and then clang reported **29 errors in
the generated C**.

**Nothing had said so because nothing had asked.** Of the gate scripts here, exactly one compiles
anything, and it was written today — until then every number in the README was an interpreted number.
A library that only ever runs interpreted has untested portability and no gate is in a position to
notice. The counts below are the two halves of that, and the first of them was itself wrong on the
first run: 16 was a guess and the answer is 15.

- **Number:** `2` = `grep -l 'MERE" -c' scripts/*_check.sh | grep -c ''`
- **Number:** `16` = `ls scripts/*_check.sh | grep -c ''`
- **Number:** `4` = `sed -n 's/.*EXPECT_PASS:-\([0-9]*\).*/\1/p' scripts/compiled_check.sh`

The first version of that command was `grep -lc`, which is `-l` and `-c` together and unspecified —
it printed 1 in one shell and 16 in another, and the gate reported it stale on its first run. Two
answers from one expression, and the wrong one was the one that looked like the right one.

**Two independent families, and the split was measured rather than guessed** — renaming three
identifiers took the count from 29 to 14, so the remainder is not a consequence of the first.

### 1. A C keyword used as a binder becomes a C keyword in a struct (15 of the 29)

A lifted inner function's captures become the fields of a C struct, and the names go through
unescaped. `src/style.mere` had `fn (short: str) -> fn (long: str)` and `src/layout.mere` had
`fn (inline: str)`, so the backend emitted `const char* short;` and the generated C did not parse.
Two lines reproduce it, and the interpreter is right:

    type t = { short: str };
    let v = t { short = "x" } in print v.short

Same site family as mere v0.1.280, where a module-qualified capture name reached the same emitter
verbatim and produced `long long Wire.delimited;`. That fix flattened dots in three places; escaping
was not part of it, and a keyword is the other way the same field name can be invalid.

**Worked around here, not fixed.** The three binders are renamed with a comment pointing at this
entry, the way `contrib/http2`'s naming workaround became a comment about history.

### 2. A capture two levels of lifting away is not threaded (14 of the 29)

Ten lines, and the interpreter answers 9:

    type r = { id: int, n: int };
    let outer = fn (id: int) ->
      let mid = fn (xs: r list) ->
        let rec inner = fn (ys: r list) ->
          match ys with
          | Nil -> r { id = id, n = 0 }
          | Cons (y, rest) -> if y.id == id then y else inner rest
        in inner xs
      in mid [r { id = 1, n = 7 }, r { id = 2, n = 9 }];
    print (str_of_int (outer 2).n)

**Measured, not assumed, in two directions.** Renaming `id` throughout keeps the two errors, so it is
not about the identifier; removing the middle function drops it to zero, so it is the DEPTH. One level
of lifting threads the capture and two do not.

This is the shape mere v0.1.283 recorded in `contrib/graphql` — "two inner functions captured a
variable two levels of lifting away" — and resolved by having the userland functions take the value as
a parameter. The compiler side is still open, and `src/jpeg.mere` is where it lands here.

### Closed, both families, upstream

**Family 1** was fixed by routing a closure capture's name through `c_safe_name`, the `mu_` prefix
v0.1.56 chose over a reserved-word list. The two paths that build that struct were disagreeing about
it — the inner-lifted one had always prefixed — which is the second time the same pair disagreed
about the same struct.

**Family 2 was two holes, not one** (mere v0.1.286). `known` decides what is not captured and
`host_locals` is what rescues a name from it; a curried parameter's name was discarded by the
walker's own `Fun` case, and descending into a lifted body reset the list to empty. **Three things
have to line up** — the name shadows a builtin, it is a curried parameter or read from a nested lift,
and it is read from a lifted function — which is why a decade of programs never hit it and one
browser did.

**And the reason this entry existed now has a gate.** `scripts/compiled_check.sh` compiles the engine
and requires the binary to answer what the interpreter answers, document for document. "It compiles"
is the weaker half: a backend can compile and be wrong, so the interpreter is the oracle, the same
way it is for the language's own cross-backend parity. Poisoned two ways — a build that fails reports
the errors rather than the fact, and a document dropping silently out of the sample fails the count.

The measurement `scripts/northstar_measure.sh` owed: a 559-byte page in 44 ms, of which 19 is loading
the font and 17 is style and layout, at a 39 MiB high-water mark.

**What is still open is the other keyword surface**, and it is a separate entry's worth: a user
RECORD field called `short` still emits a C keyword. Record fields are a different struct reached
from about a dozen sites — typedef, construction, update, access, `show_`, `to_json`, `from_json`,
`eq`, pattern binding — and nothing here reaches it.
