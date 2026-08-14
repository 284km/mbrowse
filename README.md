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

## CSS component values

`test/data/css_*.json` is [css-parsing-tests](https://github.com/CourtBouillon/css-parsing-tests),
126 cases across every level from component values to a whole stylesheet — what
css-parsing-tests is to CSS is what html5lib-tests is to HTML. It is vendored and pinned by
SHA, and it was **here before any parser was**.

```
sh scripts/css_check.sh          # component values: 50 of 50
```

`src/css_tokens.mere` is the tokenizer and the component value parser, split where the
standard splits them: the tokenizer answers *what is this token* and the parser answers
*what is this token inside of*, which needs a stack the scanner does not have. **All 50
cases pass with nothing exempted and nothing left uncompared.** One thing is deliberately
not compared — the numeric *value* of a number, because the value is arithmetic on the
representation (the suite writes `+45.0` as 45) and comparing it would compare how two
languages print a float rather than what the tokenizer decided.

Getting there cost three wrong estimates of the same pile, which is the part worth keeping.
It started as one bucket of 34 cases labelled "blocks and functions". Splitting it found 13
that only wanted a number to say more about itself. Splitting what was left found 9
`unicode-range` cases and 2 hash flags, neither of which is a tree. **A bucket is a claim
about what is left in it**, and this one was wrong three times in a row — each time in the
direction of making the remaining work sound like one big thing.

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
