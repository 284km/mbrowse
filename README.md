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

Finding a normative suite for tree construction — web-platform-tests is the obvious
place to look next — comes before writing many more of these by hand. What is there is
an `encoding` suite, which is the gate for the character-encoding sniffing that reads
`<meta charset>`, and that is the next thing to need one.

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
