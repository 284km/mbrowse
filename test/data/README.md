# Vendored corpora

Every gate in this repository compares against one of these. All are pinned — by SHA
where the upstream has moved, which two of the three have.

| files | what | pinned |
|---|---|---|
| `tree_tests*.dat` | html5lib-tests, tree construction (189 cases) | SHA — the data moved to WPT after that commit |
| `encoding_tests*.dat` | html5lib-tests, encoding sniffing (81 cases) | branch |
| `css_*.json` | css-parsing-tests (126 cases) | SHA — the repository moved from SimonSapin to CourtBouillon |

## The .dat format (HTML)

Blocks separated by blank lines. `#data` then the source, `#errors`, then `#document`
and the expected tree — one node per line, two spaces per level, each line prefixed
`| `. `scripts/tree_cases.py` strips the prefix and compares against what
`src/dom.mere` serializes, which is the same shape without the bar.

`#document-fragment` marks a case for the fragment algorithm. **There are none in
tests1 through tests3** — the harness has reported "0 skipped (fragment)" every run
since it was written, which is a number worth reading rather than passing over.

## The css-parsing-tests format

One flat JSON array, alternating input string and expected result — so the case count
is half the array length. A component value is either

* a **string**, for a token that is only itself: `"/"`, `"*"`, `" "` for any run of
  whitespace, `"-->"` for a CDC, `"<!--"` for a CDO;
* or a **two-element array** naming it: `["ident", "red"]`, and likewise `number`,
  `string`, `function`, `at-keyword`, `hash`, `url`, `dimension`, `percentage`.

Worth noticing before writing the tokenizer, because both are in the same list and a
renderer that emits only one shape cannot match:

```
'red/* CDC */-->'      => [["ident", "red"], "-->"]
'red-->/* Not CDC */'  => [["ident", "red--"], ">"]
```

The second is not a CDC. `-->` only ends a comment-like construct at the start of a
component value; inside an identifier the dashes belong to the name, and what is left
is a lone `>` delim. Comments are removed before any of this, which is why the first
case has a CDC at all and why `/*/*///** /* **/*//* ` is `["/", "*", "/"]`.
