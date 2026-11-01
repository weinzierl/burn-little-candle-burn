// Speaker notes with slide thumbnails, sized for reading on a phone.
// Build from the repository root:
//   typst compile --root . --ignore-system-fonts --font-path fonts/public \
//     --input deck=/presentation-public.pdf notes/speaker-notes.typ speaker-notes.pdf
// The thumbnails are the real slide pages, embedded as vector graphics.

#let deck = sys.inputs.at("deck", default: "/presentation-public.pdf")
#let notes = yaml("notes.yaml")

#let ink = rgb("#111111")
#let grey = rgb("#5F6368")
#let rule = rgb("#D6D4CF")
#let accent = rgb("#B3301A")

// Inline code in notes: text between backticks becomes raw.
#let rich(s) = {
  for (i, p) in s.split("`").enumerate() {
    if calc.rem(i, 2) == 1 { raw(p) } else { p }
  }
}

#let mmss(s) = {
  let m = calc.floor(s / 60)
  let r = calc.rem(s, 60)
  str(m) + ":" + (if r < 10 { "0" } else { "" }) + str(r)
}

#set document(title: "Speaker notes: Burn, little candle, burn!", author: "Ludwig Weinzierl")
#set page(width: 110mm, height: auto, margin: (x: 6mm, top: 6mm, bottom: 8mm), fill: white)
#set text(font: "Jost", size: 10.5pt, fill: ink, fallback: false, lang: "en", hyphenate: false)
#set par(leading: 0.55em, spacing: 0.9em, justify: false)
#show raw: set text(font: "IBM Plex Mono", size: 0.92em, fallback: false)
#set list(marker: box(width: 0.32em, height: 0.32em, fill: accent, baseline: -0.28em), spacing: 0.6em)

// Totals. Backup slides come after the end, for questions only: not in the plan.
#let is-backup(n) = n.at("backup", default: false)
#let talk = notes.filter(n => not is-backup(n))
#let n-backup = notes.len() - talk.len()
#let total = talk.map(n => n.time).sum()
#let skippable = talk.filter(n => n.at("skip", default: false)).map(n => n.time).sum()

// ---- cover: running order ----
#text(font: "IBM Plex Mono", size: 8pt, fill: grey)[RUSTLAB 2026 · BOLOGNA · 2 NOVEMBER, 11:30 · 45 MIN SLOT]
#v(2pt)
#text(size: 17pt, weight: 600)[Burn, little candle, burn!]
#v(-4pt)
#text(size: 12pt, fill: grey)[Speaker notes]
#v(4pt)
#grid(
  columns: (1fr, 1fr, 1fr),
  column-gutter: 4pt,
  [#text(size: 8pt, fill: grey)[planned] \ #text(size: 13pt, weight: 600)[#mmss(total)]],
  [#text(size: 8pt, fill: grey)[skippable] \ #text(size: 13pt, weight: 600)[#mmss(skippable)]],
  [#text(size: 8pt, fill: grey)[slides] \ #text(size: 13pt, weight: 600, str(talk.len()) + if n-backup > 0 { " + " + str(n-backup) } else { "" })],
)
#v(4pt)
#text(size: 9pt)[Each page: slide, planned time, the clock time at the end of the slide, short cues, then the full notes. *SKIP* marks slides to drop when running late. *BACKUP* slides come after the end, for questions only.]
#v(4pt)
#{
  let acc = 0
  set text(size: 8.5pt)
  let rows = ()
  for (i, n) in notes.enumerate() {
    let backup = is-backup(n)
    if not backup { acc += n.time }
    let skip = n.at("skip", default: false)
    rows.push((
      str(i + 1),
      text(fill: if skip or backup { grey } else { ink }, n.title),
      if backup { [] } else { mmss(n.time) },
      if backup { [] } else { mmss(acc) },
      if skip { text(fill: accent, weight: 600)[skip] } else if backup { text(fill: grey, weight: 600)[backup] } else { [] },
    ))
  }
  table(
    columns: (auto, 1fr, auto, auto, auto),
    align: (right, left, right, right, left),
    stroke: (x, y) => (top: if y == 1 { 0.8pt + ink } else if y > 1 { 0.3pt + rule } else { none }),
    inset: (x: 3pt, y: 2.6pt),
    table.header([#text(fill: grey)[\#]], [#text(fill: grey)[slide]], [#text(fill: grey)[time]], [#text(fill: grey)[at]], []),
    ..rows.flatten(),
  )
}

// ---- one page per slide ----
#let acc = 0
#for (i, n) in notes.enumerate() {
  let backup = is-backup(n)
  if not backup { acc += n.time }
  let skip = n.at("skip", default: false)
  pagebreak()
  grid(
    columns: (1fr, auto),
    text(font: "IBM Plex Mono", size: 8.5pt, fill: grey)[#(i + 1) / #notes.len() · #if backup [for questions] else [#mmss(n.time) · at #mmss(acc)]],
    if skip { text(font: "IBM Plex Mono", size: 8.5pt, fill: accent, weight: 600)[SKIP] } else if backup { text(font: "IBM Plex Mono", size: 8.5pt, fill: grey, weight: 600)[BACKUP] },
  )
  v(1pt)
  text(size: 13pt, weight: 600, n.title)
  v(2pt)
  box(stroke: 0.5pt + rule, image(deck, page: i + 1, width: 100%))
  v(4pt)
  block(
    fill: rgb("#F3F2EF"),
    inset: (x: 7pt, y: 6pt),
    width: 100%,
    {
      set text(size: 11pt, weight: 500)
      for cue in n.cue { list(rich(cue)) }
    },
  )
  v(4pt)
  for para in n.notes.trim().split("\n\n") {
    par(rich(para.replace("\n", " ")))
  }
  if "qa" in n {
    v(2pt)
    for qa in n.qa {
      block(
        stroke: (left: 1.5pt + accent),
        inset: (left: 6pt, y: 2pt),
        [#text(weight: 600)[Q: #rich(qa.q)] \ #text(fill: ink)[A: #rich(qa.a)]],
      )
    }
  }
}
