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

**What the checks are not yet**: html5lib-tests' tree-construction suite is not
vendored — its files are not where the tokenizer's are and the path has to be found
first — so `test/tree_check.mere` is hand-written, which is the weaker kind of
evidence: those are the cases we thought of.

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
