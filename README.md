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

Early. The document tree, its serializer, and the insertion modes on the path every
ordinary document takes — enough to turn `<p>hi<p>there` into a document with the
html, head and body elements nobody wrote and the two paragraphs as siblings.

Dependencies are vendored into `.mere_modules/` (Mere resolves
`import "<package>/<module>.mere"` by walking up to the nearest one) and committed,
so a checkout builds without fetching anything. `scripts/vendor.sh` is what put them
there.

**What the checks are not yet**, and the reason is worth stating: html5lib-tests
**has no tree-construction suite**. Its directories are `encoding`, `lint_lib`,
`serializer` and `tokenizer` — the tree-construction data that every parser used to be
measured against is not in that repository, and assuming it was is what this looked
for first. So `test/tree_check.mere` is hand-written, which is the weaker kind of
evidence: those are the cases we thought of.

For encoding sniffing there **is** one, and it is wired up: `scripts/encoding_check.sh`
runs html5lib-tests' encoding suite, **67 of 81**. It was 46 until the label table
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
workaround. `scripts/tree_check.sh` runs it: **109 of 189**, pinned exactly.

Most of what fails needs things that are not here yet — a tokenizer state chosen by
the builder (many cases start in one), the table insertion modes, foreign content,
the adoption agency algorithm. None of it is excused: every case is a pass or a
failure, because an exemption bucket hides real failures the moment the feature it
excuses arrives. What is there is
an `encoding` suite, which is the gate for the character-encoding sniffing that reads
`<meta charset>`, and that is the next thing to need one.

## Layout, and its gate before it

```
sh scripts/layout_check.sh        # geometry: 0 of 126, box sequence: 126 of 126
```

The gate exists and the engine does not, which is the same order the CSS corpus arrived in. Both
halves of it come from somewhere other than here: the 126 documents are web-platform-tests' CSS 2
normal-flow reftests, self-contained with their CSS inline, chosen by the people who wrote the
specification; the expected geometry is `getBoundingClientRect` from a real browser, taken once
at vendoring time and committed.

**Reftests are the wrong gate to start with.** The plan for this layer said WPT reftests, and a
reftest compares two of *your own* renderings — so an engine that draws nothing passes every one.
That is the trap the window capability hit, where a readback handed back the pixels just written
and every comparison passed; it took poisoning the buffer to see it. Geometry from another engine
cannot be passed by drawing nothing, because the numbers are specific. Reftests are still worth
running later, for what geometry does not check: colour, stacking, and where the ink lands.

Two numbers are reported, because they fail for different reasons. The **box sequence** — which
elements generate boxes, in what order — is the parser and the box tree, and it is already right
for all 126. The **geometry** is layout, and it is right for none of them: there is no style
resolution, so the 8px margin on `body` and the 1em on a `<p>` that are in every expectation are
missing, and no text measurement, so a box holding only text has no height. Reporting one number
would hide a broken parse behind a missing property, or call a blank page a success.

## Where the tree builder is

```
sh scripts/tree_check.sh          # html5lib tree construction: 176 of 189
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
