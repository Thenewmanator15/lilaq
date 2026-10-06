#import "/src/lilaq.typ" as lq
#import "@preview/tiptoe:0.4.0"
#set page(width: auto, height: auto, margin: 6pt)
#set text(size: 9pt)

#let f = lq.logspace(3, 8, num: 60)
#let lp(fc) = f.map(x => 1 / calc.sqrt(1 + calc.pow(x / fc, 2)))

#grid(columns: 2, gutter: 8pt,
  lq.diagram(
    width: 7cm, height: 4.5cm,
    xscale: "log", yscale: "log",
    xlabel: [Frequency (Hz)], ylabel: [Gain],
    lq.plot(f, lp(1e5), mark: none,
      annotations: (
        lq.annotation(3e6)[Conventional],
        lq.annotation(1e5, offset: (-2.2em, 2.2em), leader: tiptoe.stealth)[corner],
      )),
    lq.plot(f, lp(3e6), mark: none,
      annotations: lq.annotation(4e7, side: bottom)[Wideband]),
    lq.line((1e3, 0.707), (1e8, 0.707), stroke: (dash: "dashed", paint: gray, thickness: .5pt),
      annotations: lq.annotation(10%, side: bottom, fill: gray)[$-3$ dB]),
  ),
  {
    let xs = lq.linspace(0, 10, num: 80)
    lq.diagram(
      width: 7cm, height: 4.5cm,
      lq.plot(xs, xs.map(x => calc.sin(.6 * x)), mark: none,
        annotations: (
          lq.annotation(55%)[by ratio],
          lq.annotation(2.6, offset: (3em, -.2em))[peak],
        )),
      lq.plot(xs, xs.map(x => .1 * x - 1), mark: none,
        annotations: lq.annotation(7.5, side: bottom)[linear]),
    )
  }
)
