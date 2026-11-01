# Fonts

The slides use three typefaces. Only the freely licensed ones are in this repository.

| Role | Public build | Private build | License |
|---|---|---|---|
| Headlines | Kumbh Sans (Saurabh Sharma) | Ergonomique Bold and Black (Paulo Goode) | Kumbh Sans: SIL OFL 1.1. Ergonomique: Fontspring Desktop Font EULA 1.7.0, not distributed |
| Body, labels, diagrams | Jost (Owen Earl, indestructible type*) | same | SIL OFL 1.1 |
| Code and terminal | IBM Plex Mono (IBM) | same | SIL OFL 1.1, Reserved Font Name "Plex" |

- `fonts/public/` holds the unmodified font files from the google/fonts repository and their license texts (`OFL-*.txt`). Jost and Kumbh Sans are variable fonts; Typst picks the weights.
- `fonts/private/` is for a licensed copy of Ergonomique (the `.otf` files; the slides use `ergonomique-bold.otf` and `ergonomique-black.otf`). Its contents are ignored by git and are not part of any release.

## Why Kumbh Sans

Ten free candidates were compared by eye with Ergonomique Semibold; four of them (Kumbh Sans, Comme, Gantari, Figtree) were then measured at weight 600. Kumbh Sans has the closest proportions. The deck has since moved to Bold (700) for titles and Black (800 in Ergonomique) for section numbers; Kumbh Sans covers both through its weight axis (100 to 900), and Typst renders each weight as its own instance. Here it is next to Comme, the substitute used before the licensed files were available:

| Measure (weight 600) | Ergonomique | Kumbh Sans | Comme |
|---|---|---|---|
| x-height, em | 0.493 | 0.488 | 0.528 |
| width of n / x-height | 0.99 | 0.98 | 0.88 |
| width of o / x-height | 1.12 | 1.06 | 0.96 |
| mean advance, a to z, em | 0.546 | 0.545 | 0.543 |
| the 46 slide titles (as listed in the notes) at 38 pt | 20 394 pt | 19 761 pt (3.1 % narrower) | 20 617 pt (1.1 % wider) |

## Embedding and licenses

- PDFs embed font subsets. The SIL OFL permits embedding and redistribution of Jost, IBM Plex Mono and Kumbh Sans.
- Ergonomique is licensed under the Fontspring Desktop Font EULA 1.7.0 (the text comes with the licensed font files). The parts that matter here:
  - Section 2d: documents that embed the font and are sent to third parties must be read-only for the recipients. A PDF with an embedded subset and no form fields, like `presentation-private.pdf`, is a read-only document in the usual reading; that is my reading, not legal advice.
  - Section 6: no modified fonts or derivatives, except files generated for embedding (Typst embeds a subset).
  - Section 3: a contractor working for the licensee may use the font temporarily and keeps no copies when the work is done.
- The font files themselves are never distributed: not in git, not in the source zip, not in the public PDF.

Sources: https://github.com/google/fonts (`ofl/jost`, `ofl/ibmplexmono`, `ofl/kumbhsans`), https://github.com/xconsau/KumbhSans, https://paulogoode.com/ergonomique
