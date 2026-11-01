// theme.typ: the small amount of structure the deck needs.
//
// Font profile, chosen on the command line:
//   typst compile --input fonts=public  ...  (Kumbh Sans headlines, redistributable)
//   typst compile --input fonts=private ...  (Ergonomique headlines, licensed copy)

#let profile = sys.inputs.at("fonts", default: "public")
#assert(
  profile in ("public", "private"),
  message: "use --input fonts=public or --input fonts=private",
)

#let fonts = (
  head: if profile == "private" { "Ergonomique" } else { "Kumbh Sans" },
  body: "Jost",
  mono: "IBM Plex Mono",
)

// Style: 1970s Swiss, after Ludwig's "seventies" kit. Full-bleed flat colour,
// one bold cream line on the same horizon on every slide (after Osvaldo
// Cavandoli's La Linea). The line can rise into frames, plinths and candles.
// Text is cream on dark fields (contrast 4.1 or more) and black on ochre.
// Meaning is never carried by colour alone.

#let ink = (
  teal: rgb("#36677A"),
  ochre: rgb("#C99A3B"),
  brick: rgb("#B04F3B"),
  olive: rgb("#6B7345"),
  plum: rgb("#5B4757"),
  slate: rgb("#2C393E"),
  black: rgb("#262626"),
  cream: rgb("#EFE8D8"),
  sand: rgb("#D9CDB3"),
  gold: rgb("#E0AE4E"),
)

#let c = (
  ink: ink.cream,
  grey: ink.cream,
  rule: ink.cream.transparentize(60%),
  code-bg: ink.slate,
  term-bg: ink.black,
  term-ink: ink.cream,
  accent: ink.gold,
  paper: ink.teal,
)

// 16:9, in points: 960 x 540. The horizon is 468 pt from the top.
#let W = 960pt
#let H = 540pt
#let base = 468
#let weight = 7pt
#let margin = (left: 56pt, right: 56pt, top: 46pt, bottom: 88pt)

// A point in page coordinates (pt).
#let P(x, y) = (x * 1pt, y * 1pt)

// The line: Typst curve segments in page coordinates.
#let linea(..cmds, color: ink.cream, thickness: weight) = place(top + left, curve(
  stroke: (paint: color, thickness: thickness, cap: "round", join: "round"),
  ..cmds,
))

// An unbroken horizon from edge to edge.
#let ground = (curve.move(P(-10, base)), curve.line(P(970, base)))

// Up, across, down: frames, plinths, diagram nodes.
#let arch(x0, x1, top, r: 10) = (
  curve.line(P(x0, base)),
  curve.line(P(x0, top + r)),
  curve.quad(P(x0, top), P(x0 + r, top)),
  curve.line(P(x1 - r, top)),
  curve.quad(P(x1, top), P(x1, top + r)),
  curve.line(P(x1, base)),
)

// A line through `pts` (page coordinates, axis-parallel segments), each inner
// corner rounded with the matching radius in `r` (0 keeps it square).
#let polyline(pts, r) = {
  let d(a, b) = if a == b { 0 } else if b > a { 1 } else { -1 }
  let segs = (curve.move(P(..pts.first())),)
  for i in range(1, pts.len() - 1) {
    let (x, y) = pts.at(i)
    let (px, py) = pts.at(i - 1)
    let (nx, ny) = pts.at(i + 1)
    let ri = r.at(i - 1)
    if ri == 0 {
      segs.push(curve.line(P(x, y)))
    } else {
      segs.push(curve.line(P(x - d(px, x) * ri, y - d(py, y) * ri)))
      segs.push(curve.quad(P(x, y), P(x + d(x, nx) * ri, y + d(y, ny) * ri)))
    }
  }
  segs.push(curve.line(P(..pts.last())))
  segs
}

// A horizon that rises into arches between `pairs` of (x0, x1, top).
#let arches(..specs) = (
  curve.move(P(-10, base)),
  ..specs.pos().map(((x0, x1, t)) => arch(x0, x1, t)).flatten(),
  curve.line(P(970, base)),
)

// The candle, drawn by the line: up, across to the wick, a flame (or smoke), back, down.
#let candle(x0, x1, top, lit: true) = {
  let wx = (x0 + x1) / 2
  let wt = top - 22
  (
    curve.line(P(x0, base)),
    curve.line(P(x0, top)),
    curve.line(P(wx, top)),
    curve.line(P(wx, wt)),
    ..if lit {(
      curve.cubic(P(wx - 30, wt - 10), P(wx - 16, wt - 52), P(wx + 2, wt - 78)),
      curve.cubic(P(wx + 16, wt - 52), P(wx + 30, wt - 10), P(wx, wt)),
    )} else {(
      curve.cubic(P(wx - 24, wt - 26), P(wx + 26, wt - 52), P(wx - 4, wt - 86)),
      curve.cubic(P(wx - 22, wt - 106), P(wx + 18, wt - 124), P(wx + 6, wt - 140)),
      curve.cubic(P(wx + 18, wt - 124), P(wx - 22, wt - 106), P(wx - 4, wt - 86)),
      curve.cubic(P(wx + 26, wt - 52), P(wx - 24, wt - 26), P(wx, wt)),
    )},
    curve.line(P(wx, top)),
    curve.line(P(x1, top)),
    curve.line(P(x1, base)),
  )
}
#let flame-fill(x0, x1, t) = {
  let wx = (x0 + x1) / 2
  let wt = t - 22
  place(top + left, curve(
    fill: ink.ochre,
    stroke: none,
    curve.move(P(wx, wt)),
    curve.cubic(P(wx - 30, wt - 10), P(wx - 16, wt - 52), P(wx + 2, wt - 78)),
    curve.cubic(P(wx + 16, wt - 52), P(wx + 30, wt - 10), P(wx, wt)),
    curve.close(),
  ))
}

// Letterspaced capitals for small labels.
#let caps(body, size: 13pt, weight: 500, color: ink.cream) = text(
  font: "Jost", weight: weight, size: size, tracking: 0.14em, fill: color, upper(body),
)

// The colour of the current slide, for elements that must contrast with it.
#let slide-bg = state("slide-bg", ink.teal)

#let deck(body) = {
  set document(
    title: "Burn, little candle, burn!",
    author: "Ludwig Weinzierl",
  )
  set page(width: W, height: H, margin: margin, fill: ink.teal)
  set text(
    font: fonts.body,
    size: 26pt,
    fill: ink.cream,
    fallback: false,
    lang: "en",
    hyphenate: false,
  )
  set par(leading: 0.5em, justify: false)
  set list(
    marker: box(baseline: -0.12em, circle(radius: 0.17em, fill: ink.gold)),
    body-indent: 0.6em,
    spacing: 0.75em,
  )
  set raw(theme: "code.tmTheme")
  show raw: set text(font: fonts.mono, fallback: false)
  show strong: set text(weight: 600)
  // Names that must not break at their hyphen.
  show regex("Cortex-M33|SmolLM2-360M-Instruct|x86-64|mps2-an505|burn-store|burn-onnx|candle-onnx|llama2\\.c"): it => box(it)
  body
}

// The footer sits under the horizon.
#let footer(color: ink.cream) = place(top + left, dx: margin.left, dy: (base + 30) * 1pt, block(
  width: W - margin.left - margin.right,
  grid(
    columns: (1fr, auto),
    caps(size: 13pt, color: color)[Burn, little candle, burn! #h(18pt) RustLab Bologna 2026],
    context {
      let n = counter(page).get().first()
      caps(size: 13pt, color: color, if n < 10 { "0" + str(n) } else { str(n) })
    },
  ),
))

// Small uppercase label: what a slide shows and where it ran.
#let tag-text(t, color: ink.cream) = caps(t, size: 13pt, color: color)

// One slide. `line` replaces the plain horizon, `art` sits under the line.
#let slide(id: none, title: none, tag: none, bg: ink.teal, line: none, art: none, body) = page(
  fill: bg,
  background: {
    if art != none { art }
    linea(..if line == none { ground } else { line })
    footer()
  },
)[
  #slide-bg.update(bg)
  #if id != none [#metadata(id) <slide-id>]
  #if tag != none { place(top + left, dy: -28pt, tag-text(tag)) }
  #if title != none {
    block(below: 20pt, text(font: fonts.head, weight: 700, size: 38pt, title))
  }
  #body
]

// Section divider on ochre: black type, the horizon rises into a plinth for the numeral.
#let section-slide(id: none, num: "", title: "", question: none, bg: ink.ochre) = page(
  fill: bg,
  background: linea(
    curve.move(P(-10, base)),
    ..arch(560, 860, 300, r: 0),
    curve.line(P(970, base)),
  ),
)[
  #slide-bg.update(bg)
  #if id != none [#metadata(id) <slide-id>]
  #set text(fill: ink.black)
  #place(top + left, dx: 560pt - margin.left, dy: -margin.top, box(width: 288pt, height: 282pt, align(
    right + bottom,
    text(font: fonts.head, weight: 800, size: 200pt, tracking: -0.04em, top-edge: "cap-height", bottom-edge: "baseline", num),
  )))
  #place(top + left, dy: 4pt, block(width: 470pt)[
    #text(font: fonts.head, weight: 700, size: 54pt)[#set par(leading: 0.2em); #title]
    #if question != none {
      v(10pt)
      text(size: 28pt, question)
    }
  ])
]

// Title page: the line rises into a lit candle.
#let title-slide(id: "title", bg: ink.teal, title: [], subtitle: none, author: none, event: none) = page(
  fill: bg,
  background: {
    flame-fill(650, 790, 230)
    linea(curve.move(P(-10, base)), ..candle(650, 790, 230), curve.line(P(970, base)))
  },
)[
  #slide-bg.update(bg)
  #metadata(id) <slide-id>
  #block(width: 560pt, height: 100%)[
    #set par(spacing: 0pt)
    #set block(spacing: 0pt)
    #caps(event, size: 20pt)
    #v(1fr)
    #text(font: fonts.head, weight: 700, size: 80pt, tracking: -0.015em)[#set par(leading: 0.18em); #title]
    #if subtitle != none { v(26pt); text(size: 28pt, subtitle) }
    #v(30pt)
    #if author != none { caps(author, size: 20pt) }
    #v(6pt)
  ]
]

// Last page: the candle is out.
#let end-slide(id: "end", bg: ink.plum, body) = page(
  fill: bg,
  background: linea(curve.move(P(-10, base)), ..candle(700, 810, 262, lit: false), curve.line(P(970, base))),
)[
  #slide-bg.update(bg)
  #metadata(id) <slide-id>
  #body
]

// ---- source snippets, cut from the real files by ANCHOR markers ----

#let dedent(lines) = {
  let indents = lines
    .filter(l => l.trim() != "")
    .map(l => l.len() - l.trim(at: start).len())
  let n = if indents.len() == 0 { 0 } else { calc.min(..indents) }
  lines.map(l => if l.len() >= n { l.slice(n) } else { l.trim() })
}

#let snippet(path, anchor) = {
  let lines = read(path).split("\n")
  let out = ()
  let inside = false
  for l in lines {
    let t = l.trim()
    if t == "// ANCHOR: " + anchor { inside = true; continue }
    if t == "// ANCHOR_END: " + anchor { inside = false; continue }
    if inside and not t.starts-with("// ANCHOR") { out.push(l) }
  }
  assert(out.len() > 0, message: "empty snippet " + anchor + " in " + path)
  dedent(out).join("\n")
}

// For files without ANCHOR markers: from the first line containing `from`
// through the first later line containing `to`, dedented.
#let cut(path, from, to) = {
  let lines = read(path).split("\n")
  let start = lines.position(l => l.contains(from))
  assert(start != none, message: "not found in " + path + ": " + from)
  let rest = lines.slice(start)
  let end = rest.position(l => l.contains(to))
  assert(end != none, message: "not found in " + path + ": " + to)
  dedent(rest.slice(0, end + 1)).join("\n")
}

// `n` lines from the first line containing `from`, dedented.
#let cut-n(path, from, n) = {
  let lines = read(path).split("\n")
  let start = lines.position(l => l.contains(from))
  assert(start != none, message: "not found in " + path + ": " + from)
  dedent(lines.slice(start, start + n)).join("\n")
}

// Break source lines longer than `max` characters for display: at the last
// space before `max`, continued on the next line after a "↪" marker.
#let wrap-src(src, max: 72) = {
  let out = ()
  for line in src.split("\n") {
    let chars = line.clusters()
    let first = chars.position(ch => ch != " ")
    let indent = if first == none { 0 } else { first }
    while chars.len() > max {
      let pos = none
      for (i, ch) in chars.slice(0, max).enumerate() {
        if ch == " " and i > indent + 8 { pos = i }
      }
      if pos == none { break }
      out.push(chars.slice(0, pos).join().trim(at: end))
      let tail = chars.slice(pos + 1)
      let k = tail.position(ch => ch != " ")
      let tail = if k == none { () } else { tail.slice(k) }
      chars = (" " * (indent + 4)).clusters() + ("↪", " ") + tail
    }
    out.push(chars.join())
  }
  out.join("\n")
}

// Verbatim lines [from, to) of a captured output file (0-based).
#let out-lines(path, from: 0, to: none) = {
  let lines = read(path).trim(at: end).split("\n")
  let to = if to == none { lines.len() } else { to }
  lines.slice(from, to).join("\n")
}

#let label-text(t) = caps(t, size: 14pt, weight: 600)

// Source code block (light). Long lines can be wrapped for display with
// `wrap: N`; continuations start with an accent "↪".
#let code(src, lang: "rust", size: 21pt, label: none, width: 100%, wrap: none) = {
  if label != none { block(below: 6pt, label-text(label)) }
  let src = if wrap == none { src } else { wrap-src(src, max: wrap) }
  // Code sits on a slate panel; on a slate slide the panel is black.
  context block(
    fill: if slide-bg.get() == ink.slate { ink.black } else { ink.slate },
    inset: (x: 16pt, y: 12pt),
    width: width,
    {
      set par(leading: 0.42em)
      show raw: set text(size: size)
      show "↪": set text(fill: c.accent)
      raw(src, lang: lang, block: true)
    },
  )
}

// Captured prose output (dark), wrapped at word boundaries for the slide.
#let prose-out(src, size: 19pt, label: none, width: 100%) = {
  if label != none { block(below: 6pt, label-text(label)) }
  block(
    fill: c.term-bg,
    inset: (x: 16pt, y: 12pt),
    width: width,
    {
      set par(leading: 0.5em, justify: false)
      set text(font: fonts.mono, size: size, fill: c.term-ink)
      src
    },
  )
}

// A number with a caption under a rule.
#let fact(value, caption) = block(
  width: 100%,
  stroke: (top: 1.6pt + c.ink),
  inset: (top: 8pt),
  [#text(font: fonts.head, weight: 700, size: 34pt, value) \ #text(size: 17pt, fill: c.grey, caption)],
)
#let facts(..items) = grid(
  columns: (1fr,) * items.pos().len(),
  column-gutter: 16pt,
  ..items.pos(),
)

// Captured terminal output block (dark).
#let term(src, size: 19pt, label: none, width: 100%) = {
  if label != none { block(below: 6pt, label-text(label)) }
  block(
    fill: c.term-bg,
    inset: (x: 16pt, y: 12pt),
    width: width,
    {
      set par(leading: 0.42em)
      set text(fill: c.term-ink)
      show raw: set text(size: size, fill: c.term-ink)
      raw(src, block: true)
    },
  )
}

// Captured output with hard wraps at `max` characters. Continuation
// lines start with a grey arrow, so a wrap is never mistaken for output.
#let term-wrap(src, size: 18pt, max: 70, label: none) = {
  if label != none { block(below: 6pt, label-text(label)) }
  block(
    fill: c.term-bg,
    inset: (x: 16pt, y: 12pt),
    width: 100%,
    {
      set par(leading: 0.42em)
      set text(font: fonts.mono, size: size, fill: c.term-ink)
      show raw: set text(size: size, fill: c.term-ink)
      let lines = src.split("\n")
      for (i, line) in lines.enumerate() {
        let rest = line.trim(at: end).clusters()
        let first = true
        while true {
          let chunk = if rest.len() > max { rest.slice(0, max) } else { rest }
          if not first { text(fill: c.accent)[↪ ] }
          raw(chunk.join())
          rest = if rest.len() > max { rest.slice(max) } else { () }
          first = false
          if rest.len() == 0 { break }
          linebreak()
        }
        if i < lines.len() - 1 { linebreak() }
      }
    },
  )
}

// Integer with a non-breaking space as thousands separator.
#let num(n) = {
  let s = str(n)
  let out = ""
  let k = s.len()
  for (i, ch) in s.clusters().enumerate() {
    out += ch
    let left = k - i - 1
    if left > 0 and calc.rem(left, 3) == 0 { out += "\u{00A0}" }
  }
  out
}

#let ar = text(font: fonts.mono, "→")

#let note(body) = text(size: 17pt, fill: c.grey, body)

// QR codes need dark modules on a light field with a quiet zone.
// A QR code on a cream field; the field is the quiet zone (`zone` modules wide).
// `pad` overrides the zone, to give two codes the same outer size.
#let qr(path, width: 170pt, zone: 4, pad: none) = {
  let n = int(read(path).match(regex("viewBox=\"0 0 (\\d+)")).captures.at(0))
  box(fill: ink.cream, inset: if pad != none { pad } else { width / n * zone }, image(path, width: width))
}

#let big(body) = text(font: fonts.head, weight: 700, size: 44pt, body)

#let em-acc(body) = text(fill: c.accent, weight: 600, body)

// Arrow from (x0, y0) to (x1, y1), with a small filled head.
#let arrow(x0, y0, x1, y1, stroke: 1.6pt + c.ink, head: 7pt) = {
  let dx = x1 - x0
  let dy = y1 - y0
  let len = calc.sqrt(dx.pt() * dx.pt() + dy.pt() * dy.pt())
  let ux = dx.pt() / len
  let uy = dy.pt() / len
  let bx = x1 - ux * head
  let by = y1 - uy * head
  let px = -uy * head * 0.55
  let py = ux * head * 0.55
  place(line(start: (x0, y0), end: (bx, by), stroke: stroke))
  place(polygon(
    fill: stroke.paint,
    stroke: none,
    (x1, y1),
    (bx + px, by + py),
    (bx - px, by - py),
  ))
}

// A labelled box placed at (x, y) with size (w, h).
#let node(x, y, w, h, body, fill: none, stroke: 1.4pt + c.ink, size: 20pt) = place(
  dx: x,
  dy: y,
  box(
    width: w,
    height: h,
    fill: fill,
    stroke: stroke,
    inset: 6pt,
    align(center + horizon, text(size: size, body)),
  ),
)
