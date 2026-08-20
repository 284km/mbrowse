# mbrowse

A browser for static pages, written in [Mere](https://github.com/merelang/mere).

Fetch a page over HTTPS, parse it, lay it out, and draw it in a window — with real
fonts and real images, and **no JavaScript**. The point is not to compete with a
browser; it is to find out what a language is missing by writing the program that
needs the most from it.

## Where the parts live

A browser is mostly libraries that are not browser-specific, and those live in the
Mere repository rather than here:

| | |
|---|---|
| `contrib/url` | the WHATWG URL parser |
| `contrib/encoding` | the Encoding Standard's decoders |
| `contrib/unicode` | grapheme clusters, line breaking, normalization |
| `contrib/html` | the HTML **tokenizer** (1,900 of 1,900 html5lib-tests cases) |
| `contrib/raster` | antialiased polygon fill, strokes, clipping |
| `contrib/window` | a window, its pixels, and its input |

What is here is the part that is a browser: **tree construction** — turning a
stream of tokens into a document, with the insertion modes and the rules that
recover from mis-nested tags — then CSS, layout, fonts, and the paint that ties
them together.

## Status

Bytes to boxes, checked at every step against something other than itself. Encoding sniffing, an
HTML tokenizer, tree construction, CSS parsing, the cascade with inheritance, layout, and glyph
outlines down to which pixels they cover — with a gate on each, and every gate's oracle written by
somebody else.

```
sh scripts/check.sh
```

| what                   | against                        |            |
|------------------------|--------------------------------|------------|
| encoding sniffing      | html5lib-tests                 | 81 of 81   |
| tree construction      | html5lib-tests (pinned by SHA) | 185 of 189 |
| CSS, six levels        | its own corpus, level by level | 126 of 126 |
| layout geometry        | a browser's own rects          | 218 of 228 |
| layout box sequence    | the same                       | 228 of 228 |
| image boxes            | a browser's own rects          | 20 of 21   |
| image ink              | a browser's own SCREENSHOT     | 10 of 12   |
| character positions    | a browser's `Range` rects      | 112 of 228 |
| reftests               | two of our own; the PAIRING from a browser | 71 of 76 |
| font metrics           | a browser's `measureText`      | 29 of 29   |
| glyph outlines, 5 ways | fontTools                      | exact      |
| JPEG headers           | libjpeg, through Pillow        | 9 of 9     |
| JPEG pixels            | libjpeg, exactly, no tolerance | 297 of 297 |
| HTTPS fetch            | curl, over our own TLS server  | 9 of 9     |
| OPEN_QUESTIONS.md      | the gates it makes claims about | 16 checks |

The HTML **tokenizer** is not in this table and not in this repository: it is a Mere package, gated
against html5lib-tests where it lives. The line has to be drawn somewhere and it is drawn at what
this repo can break.

Character positions are 112 where the boxes are 218, and that gap is information rather than a
shortfall: **106 documents have every element box exactly where the browser puts it and at least one
character somewhere else.** No box gate can see that. The causes are ligatures — the browser
substitutes `fi` with one glyph through GSUB and nothing here does — and single-pixel drift along a
line.

**Reftests need no oracle**, and they are the only gate here that does not. Every other one asks "is
this right" and answers with something written by somebody else; a reftest asks "do these two pages
look the same", and both sides of that are ours — so nothing is committed as an expectation and
nothing is regenerated when the engine changes. Which is exactly why they could not come first: an
engine that draws nothing passes every one. The geometry is independently checked, so a blank page
would already be failing elsewhere, and the reftests are free to check what geometry cannot — colour,
what covers what, and whether the ink lands inside the box measured for it.

**A document enters as bytes, and its encoding is decided before anything reads it.** Every driver
used to open a page with `str_join "\n" (read_lines path)`, which meant this repository gated its
sniffing module and then ran a pipeline that used neither it nor a decoder. `Sniff.text` is the pair
— decide, then apply — and it is the single entry point for a page off disk and a page off a socket,
so the two differ in where the bytes came from and in nothing else.

Measured before changing it: 154 of the 228 layout documents differ between the two readings, all of
them by one to three trailing newlines that `read_lines` drops and a browser does not, and no file in
the corpus contains a CR so nothing else can differ. Every one of those documents is ASCII, which is
why the fetch corpus carries a Shift_JIS page: it is the only input here that can tell a right
encoding decision from a wrong one, and it is compared both as bytes and as the text it decodes to.

**Bytes now come off a socket as well as off disk.** `src/fetch.mere` connects, verifies the
certificate, asks for one resource and reads until the peer is done — as `bytes`, because
`mem_to_str` stops at the first zero and a page's images are full of them. `scripts/fetch_check.sh`
holds it to **curl over a TLS server this repository starts**, which is what makes it reproducible:
a live URL is a moving target, so a red run would mean "the page changed" as often as it means
anything and a green run on a machine with no network would mean nothing. Five bodies, each present
because something plausible fails on exactly one of them — zero bytes, more than one read, chunked
with a size-line extension, and a body split across two writes — plus a case requiring an untrusted
certificate to be refused, because `tcp_starttls` and `tcp_starttls_verified` pass all five
identically and without it "the certificate is checked" is a claim with nothing under it.

**And the counts in `OPEN_QUESTIONS.md` are checked too**, which they were not: `Q-6` said 61 of 109
pairs with 48 failures for a day after the gate was pinned at 71 of 76. The gate's number is
compared against reality on every run and the prose was compared against nothing, so the copy that
drifted was the one nobody could see drift. `scripts/questions_check.sh` runs each entry's stated
numbers, its reproduction, and the documents it names as failing — and requires every reproduction
to come with the input that makes it stop reproducing, because a search that finds nothing gives the
same reassuring answer as a search that is broken.

What is NOT here: a window. The picture exists as pixels and nothing puts it on a screen.

[`OPEN_QUESTIONS.md`](OPEN_QUESTIONS.md) is what this repository knows it does not know, with the
repairs that have already been tried and measured and rejected. Several of the remaining failures
have an obvious fix that costs more than it gains; that is worth more written down than a list of
failures on its own, which invites someone to try the thing that has already been tried.

Dependencies are vendored into `.mere_modules/` (Mere resolves
`import "<package>/<module>.mere"` by walking up to the nearest one) and committed,
so a checkout builds without fetching anything. `scripts/vendor.sh` is what put them
there.

**Where the tree-construction suite went**, because looking for it at its old path returns a 404
that reads like a wrong path: html5lib-tests **moved** it to web-platform-tests on 2026-06-26. Its
own directories are now `encoding`, `lint_lib`, `serializer` and `tokenizer`. It is vendored here
from the last commit before that move, by SHA.

For encoding sniffing the suite is where it always was, and it is wired up:
`scripts/encoding_check.sh` runs html5lib-tests' encoding suite, **81 of 81**. It was 46 until the label table
upstream became the Standard's full 228 — a page declaring `iso-8859-2` had been
reading as a page declaring nothing, because the table only listed encodings there was
a decoder for — and 54 until the prescan stopped reading `charset=` out of any
attribute at all. There are two forms and no third: a `charset` attribute, or a
`content` attribute on a meta whose `http-equiv` is Content-Type.
`<meta name=x content="charset=foo">` declares nothing. 54 to 67 there, and 67 to 72
when a tag stopped ending at the first `>` and started ending at its own — a quoted
attribute value may contain one, and `content="text/html; charset=x>"` ends the tag
four characters later than it looks. And 72 to **79** when the scan stopped stopping
at 1024 bytes — the standard says the prescan *may* be aborted there, and reading
"may" as "does" loses the declaration on any page whose head opens with a long
comment. **All 81 pass** since two more: an unrecognised label does not end the scan
(a page whose first meta says `charset="bogus"` and whose second says something real
has a declaration), and a tag with no `>` is not a tag — the input ended in the middle
of it.

Found, and vendored: html5lib-tests **moved** its tree-construction data to
web-platform-tests on 2026-06-26, which is why looking for it at its old path returns
a 404 that reads like a wrong path. `scripts/vendor_tests.sh` takes it from the last
commit before that move, **by SHA** — 199 cases in `test/data/tree_tests*.dat`. An
oracle is a versioned dependency; pinning is the correct form rather than a
workaround. `scripts/tree_check.sh` runs it: **185 of 189**, pinned exactly.

The four that remain are one disagreement in four costumes, and it is an ORDERING: everything
about the tree is right except that an emptied `<i>` and a `<p>` come out in the other order
among a `<div>`'s children. The suite's own `#errors` lines name `adoption-agency-1.3`,
html5lib's numbering for an OLDER version of the algorithm, so this may be the corpus's age
rather than a bug here — measured, written down, and not guessed at either way. None of it is
excused: every case is a pass or a
failure, because an exemption bucket hides real failures the moment the feature it
excuses arrives. What is there is
an `encoding` suite, which is the gate for the character-encoding sniffing that reads
`<meta charset>`, and that is the next thing to need one.

## Font metrics

```
sh scripts/font_check.sh          # widths: 29 of 29 strings
```

`src/font.mere` reads four tables and no outlines: `head` for the scale, `hhea` for how tall a line
is, `cmap` for a character's glyph, `hmtx` for its advance. The curves in `glyf` answer nothing about
where a box goes, and drawing can be wrong on its own later without moving one.

The oracle is `canvas.measureText` over the same font file, in hundredths of a pixel. It was chosen
because it already draws text correctly and reads the same bytes; a metrics reader checked against a
table somebody typed has been checked against somebody typing.

**All 29 pass.** The four that used to fail were kerning, and that was established by measurement rather
than argument: asking the same browser with `font-kerning: none` returned exactly the numbers this
produced. Kerning now comes from GPOS — this font ships no `kern` table — and the four came back without
anything else moving, which is what a diagnosis that was right looks like. The oracle was deliberately
never regenerated with kerning off; that would have fitted the oracle to the implementation, which is the
wrong direction for a gate to move.

## Layout, and its gate before it

```
sh scripts/layout_check.sh        # geometry: 218 of 228, box sequence: 228 of 228
```

The gate came before the engine, which is the same order the CSS corpus arrived in. Both halves of it
come from somewhere other than here: the 228 documents are web-platform-tests' CSS 2 normal-flow
suite — the `block-`, `blocks-`, `inline-` and `inlines-` families, self-contained with their CSS
inline, chosen by the people who wrote the specification — and the expected geometry is
`getBoundingClientRect` from a real browser, taken once at vendoring time and committed.

**Reftests are the wrong gate to start with.** The plan for this layer said WPT reftests, and a
reftest compares two of *your own* renderings — so an engine that draws nothing passes every one.
That is the trap the window capability hit, where a readback handed back the pixels just written
and every comparison passed; it took poisoning the buffer to see it. Geometry from another engine
cannot be passed by drawing nothing, because the numbers are specific. Reftests are worth running
now, for what geometry does not check — colour, stacking, where the ink lands — and they are worth
running now precisely because the geometry is independently checked first.

**Two numbers, because they fail for different reasons.** The **box sequence** — which elements
generate boxes, in what order — is the parser and the box tree. The **geometry** is layout. Reporting
one number would hide a broken parse behind a missing property, or call a blank page a success; the
table-cell commit moved geometry by zero and the sequence from 220 to 228, and one number would have
recorded it as nothing happening.

`src/style.mere` is the UA stylesheet, the selectors, the cascade and inheritance; `src/layout.mere`
is normal flow with the box model, collapsing margins, inline formatting, tables, floats and
out-of-flow boxes. **218 of the 228 pass, and the box sequence is right for all 228.**

**What widening the corpus was for.** It went from 126 documents to 228, and the reason to widen
before finishing the last few failures is in what the wider corpus said. At 126, exactly one document
used `display: inline-block`; laying it out as block-level cost that one, and the comment admitting it
was wrong read like a note for later. At 228 it was 32 of the 53 failures — the largest single thing
missing, the same defect the whole time, and nothing in the engine had changed to make it so. A corpus
does not only tell you whether you are right. It tells you what to do next, and it is the only thing
here that can.

The 10 that remain are three groups, and none of them is a feature nobody has written:

  - **four** are the block-in-inline split, where a fragment wants to be taller than its line. The
    obvious repair — union an inline's box with its descendants' — has been tried and measured twice,
    cost documents both times, and is recorded in the source as a net loss so it is not tried a third.
  - **two** need `display: inline-table` in the table algorithm, which needs three pieces at once:
    admitting it, generating the anonymous row boxes the standard wraps a stray cell in, and taking an
    inline-table's baseline from its first row. Any two of the three are worth less than none, and
    that is measured too.
  - **four** are sub-pixel. An inline-block's advance goes through a rounded pixel width, so a line of
    them accumulates a difference the browser does not have. That is a limit of the integer model
    rather than a missing rule.

## Glyphs

```
sh scripts/glyf_check.sh                  # the raw stored points:      13 of 13
MODE=segments sh scripts/glyf_check.sh    # the segments they become:   13 of 13
MODE=raster   sh scripts/glyf_check.sh    # which pixel centres inside: 13 of 13
MODE=coverage sh scripts/glyf_check.sh    # subsample coverage:          6 of 6
MODE=text     sh scripts/glyf_check.sh    # a string, placed:            6 of 6
```

Metrics first and outlines after, and the order was the point: every box in the layout gate was placed
before a single curve was read, so a bug in one can never be mistaken for a bug in the other.

The oracle is fontTools — an independent reader of the same bytes — and every comparison is **exact**,
with no tolerance on either side. Five gates over three steps, one join and one measure:

  - **the stored points**, compared raw, before any curve is flattened. An outline is hundreds of
    numbers and a reader with the flag bits slightly wrong produces a shape that is *almost* right,
    which reads as a font hint rather than as a bug.
  - **the segments**, once the two rules the file leaves implicit are applied: two off-curve points in
    a row have an on-curve point between them that is not stored, and a contour may start on one.
  - **which pixel centres are inside**, by the nonzero winding rule. Rasterising has no exact oracle —
    two rasterisers antialias differently — so the way out is to ask a weaker question of a stronger
    one: *is this centre inside* has a single answer and fontTools solves the curves to give it.
  - **subsample coverage**, and the name is the substance. Coverage's exact answer is an area no two
    rasterisers approximate alike, so what is implemented is N x N subsample coverage — a real
    antialiasing method with one answer — and it is called that rather than "area", which would have
    made the gate an excuse for the thing it checks.
  - **a whole string**, which is the only one that uses the metrics and the outlines together. Each was
    already checked alone and neither check could see the join: a reader with the right widths and the
    right shapes still draws nonsense if it advances by the wrong one.

Every one of them was poisoned on purpose and watched go red. One poison did **not** go red — ignoring
that a contour can start on an off-curve point — because no glyph in this font does that, not one of
its 3,748. That branch is written and is verified by nothing here, and the gate's header says so: a
branch nothing can exercise is not a branch anything has checked.

## Where the tree builder is## Where the tree builder is

```
sh scripts/tree_check.sh          # html5lib tree construction: 185 of 189
```

Pinned exactly, and the 13 that fail are grouped in that script's header by **what each one
needs** rather than by the tags it mentions. That distinction cost something to learn: a bucket
keyed on the input's tags once said 51 cases for a rule whose fix moved 2, because the tag a
case mentions is not the rule it is about.

The single most repeated defect in this parser has been **one predicate answering two
questions**, five times:

| the predicate | the two questions |
|---|---|
| the walk that closes an `li` | a heading closes only the current node; an li walks, skipping address, div and p |
| `_table_open` | is content inside a table's structure (a cell bounds it) vs is a table open at all (a cell is what `<td>` closes) |
| `_end_tag_matches` | scope, list-item scope, and the special-category walk are three different boundaries |
| `_is_void` | childless elements are not the same set as head elements |
| the adoption agency's boundary | where the furthest-block walk stops is not where "in scope" stops |

Every one of them looked right and passed the hand-written checks, because both readings are
plausible and the checks were written by whoever picked one. **The corpus is what knows.** Two
of the hand-written checks in `test/tree_check.mere` were themselves wrong and agreed with the
code until the corpus was asked.

## CSS component values

`test/data/css_*.json` is [css-parsing-tests](https://github.com/CourtBouillon/css-parsing-tests),
126 cases across every level from component values to a whole stylesheet — what
css-parsing-tests is to CSS is what html5lib-tests is to HTML. It is vendored and pinned by
SHA, and it was **here before any parser was**.

```
sh scripts/css_check.sh          # all six levels: 126 of 126
```

`src/css_tokens.mere` is the tokenizer and the component value parser, split where the
standard splits them: the tokenizer answers *what is this token* and the parser answers
*what is this token inside of*, which needs a stack the scanner does not have.
`src/css_rules.mere` is the five levels above — declarations, at-rules, qualified rules,
rule lists and stylesheets. **All 126 cases pass, every level pinned on its own count,
with nothing exempted and nothing left uncompared.**

The rule levels are short, and the reason is worth stating: they work on the component
value tree and never on the text. A `;` inside a block does not end a declaration and a `}`
inside a string does not end a rule — the two hard cases at that level — and both are
already gone by the time the tree exists. `@ media screen { div{;}} a:b;` is *one* invalid
declaration, and nothing in the rule code had to notice why. Checked by splitting a flat
token list instead of the tree: 8 of 10.

One thing is deliberately not compared — the numeric *value* of a number, because the value is arithmetic on the
representation (the suite writes `+45.0` as 45) and comparing it would compare how two
languages print a float rather than what the tokenizer decided.

Getting there cost three wrong estimates of the same pile, which is the part worth keeping.
It started as one bucket of 34 cases labelled "blocks and functions". Splitting it found 13
that only wanted a number to say more about itself. Splitting what was left found 9
`unicode-range` cases and 2 hash flags, neither of which is a tree. **A bucket is a claim
about what is left in it**, and this one was wrong three times in a row — each time in the
direction of making the remaining work sound like one big thing.

What the corpus decided rather than the implementer, at the rule levels: `!important` is
ASCII case-insensitive and *only* ASCII (`!İmportant` is not it), has to be the last two
values in the value (`!important!` cancels it), and does not cause the value's trailing
whitespace to be trimmed. A stylesheet ignores CDO and CDC between rules and a rule list
does not — the single difference between those two levels — while inside a prelude they are
ordinary component values in both. Each of those is one case in the suite, and the two
non-obvious ones were checked by breaking them on purpose: 20 of 21 and 13 of 16.

Three rules that arrived separately turned out to be one rule: a unit is an identifier
(`12.0-red` is twelve of the unit `-red`), an at-keyword is an identifier (`@-0media` is
not one), and a hash is flagged `id` exactly when what follows the sign could have been an
identifier. That question is now asked once, by one predicate, in the four places that ask
it.

The order — corpus first, parser second — was deliberate. Encoding sniffing in this repository went from 43 of 81 to all
81 against a normative corpus, and along the way it was wrong in both directions
alternately — too willing to read a declaration, then too blind to find one, then too
willing again. Without the corpus there was no way to know which side it was out on, only
that it was out. A CSS parser fails the same way, and the guessing is more expensive there
because the output is not a number but a page that looks nearly right.

## Building

Needs a built `mere`. See that repository for how; then:

```
mere src/main.mere > mbrowse.c
clang -O2 mbrowse.c -o mbrowse $(sdl2-config --cflags) $(sdl2-config --libs) -lm
```

## Why static pages first

The two things a browser needs that Mere does not have are a garbage collector and
loadable code, and **both are needed only by JavaScript**. A browser without it is
therefore a program the language can already express — which makes it the right
first target, and makes the JavaScript question a separate one to answer later on
evidence rather than in advance.
