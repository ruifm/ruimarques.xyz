#let cv(
  name: [],
  subtitle: [],
  author: [],
  body,
) = {
  set page(
    paper: "a4",
    margin: (x: 1.0cm, y: 0.8cm),
  )
  set text(
    font: ("Liberation Sans", "DejaVu Sans"),
    size: 9.5pt,
    lang: "en",
  )

  show link: it => text(fill: rgb("#0056b3"))[#it]

  align(center)[
    #text(size: 18pt, weight: "bold")[#name]
    #v(0.2em)
    #text(size: 11pt, style: "italic")[#subtitle]
    #v(0.3em)
    #text(size: 8pt)[#author]
  ]
  line(length: 100%, stroke: 0.5pt + black)
  v(0.5em)

  show heading.where(level: 1): it => [
    #set text(size: 14pt, weight: "bold")
    #block(above: 0.8em, below: 0.4em)[#it.body]
  ]

  show heading.where(level: 2): it => [
    #set text(size: 11pt, weight: "bold", fill: rgb("#2c3e50"))
    #block(above: 1.0em, below: 0.4em)[
      #upper(it.body)
      #v(-0.6em)
      #line(length: 100%, stroke: 1pt + rgb("#2c3e50"))
    ]
  ]

  show heading.where(level: 3): it => [
    #set text(size: 9pt, weight: "bold")
    #block(above: 0.6em, below: 0.2em)[#it.body]
  ]

  set list(indent: 1em, tight: true, spacing: 0.4em)
  set par(leading: 0.45em, justify: true)
  body
}

#show: doc => cv(
  name: [ $name$ ],
  subtitle: [ $subtitle$ ],
  author: [ $author$ ],
  doc,
)
$body$
