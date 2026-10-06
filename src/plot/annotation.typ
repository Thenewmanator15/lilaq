#import "@preview/tiptoe:0.4.0"


/// Describes an annotation that is attached to a point on a curve. It is
/// passed to @plot.annotations (or @line.annotations) and placed in screen
/// space, so it works unchanged on logarithmic axes.
///
/// Without @annotation.offset, the content sits directly on the curve and
/// follows its slope:
/// ```example
/// #let xs = lq.linspace(0, 10)
///
/// #lq.diagram(
///   lq.plot(
///     xs, xs.map(x => calc.sin(.4 * x)), mark: none,
///     annotations: lq.annotation(3)[signal]
///   )
/// )
/// ```
/// With an offset, the content is moved away from the curve and connected
/// to it with a leader line or an arrow.
#let annotation(

  /// Where on the curve to anchor the annotation. This can be
  /// - an $x$ value in data coordinates (`int` or `float`),
  /// - or the fraction of the on-screen length of the curve (`ratio`).
  /// -> int | float | ratio
  at,

  /// The content to place.
  /// -> any
  body,

  /// On which side of the curve to put the content when there is no
  /// @annotation.offset.
  /// -> top | bottom
  side: top,

  /// Space between the curve and the content when there is no
  /// @annotation.offset.
  /// -> length
  gap: .35em,

  /// Whether to turn the content to the on-screen direction of the curve.
  /// With `auto`, the content follows the curve unless an
  /// @annotation.offset is given.
  /// -> auto | bool
  follow: auto,

  /// Displaces the center of the content from the anchor by `(dx, dy)`.
  /// -> none | array
  offset: none,

  /// How to connect displaced content to its anchor. This can be `none`, a
  /// stroke, a
  /// #link("https://typst.app/universe/package/tiptoe")[tiptoe] mark which
  /// is used as the tip at the anchor, or `auto` to draw a plain line in the
  /// color of the curve.
  /// -> auto | none | stroke | tiptoe.mark
  leader: auto,

  /// How to fill the text. With `auto`, the color of the curve is used.
  /// -> auto | color
  fill: auto,

) = {
  assert(side in (top, bottom), message: "annotation: `side` must be `top` or `bottom`")
  assert(
    type(at) in (int, float, ratio),
    message: "annotation: `at` expects an x value or a ratio, got " + repr(at)
  )
  (
    at: at,
    body: body,
    side: side,
    gap: gap,
    follow: follow,
    offset: offset,
    leader: leader,
    fill: fill,
  )
}


// Finds the anchor of an annotation on a polyline that is given in screen
// space. Returns the anchor and the direction of the segment it lies on,
// all as floats in pt, or `none` if the anchor is not on the polyline.
#let find-anchor(points, at, transform) = {
  let pts = points.map(((x, y)) => (x / 1pt, y / 1pt))
  if pts.len() < 2 { return none }

  if type(at) == ratio {
    let lengths = range(pts.len() - 1).map(i => calc.sqrt(
      calc.pow(pts.at(i + 1).at(0) - pts.at(i).at(0), 2) +
      calc.pow(pts.at(i + 1).at(1) - pts.at(i).at(1), 2)
    ))
    let target = lengths.sum() * calc.clamp(at / 100%, 0, 1)
    let walked = 0
    for (i, length) in lengths.enumerate() {
      if walked + length >= target or i == lengths.len() - 1 {
        let t = if length == 0 { 0 } else { (target - walked) / length }
        let (p0, p1) = (pts.at(i), pts.at(i + 1))
        return (
          x: p0.at(0) + (p1.at(0) - p0.at(0)) * t,
          y: p0.at(1) + (p1.at(1) - p0.at(1)) * t,
          dx: p1.at(0) - p0.at(0),
          dy: p1.at(1) - p0.at(1),
        )
      }
      walked += length
    }
  }

  let px = transform(at, 1).at(0) / 1pt
  for i in range(pts.len() - 1) {
    let (p0, p1) = (pts.at(i), pts.at(i + 1))
    if calc.min(p0.at(0), p1.at(0)) <= px and px <= calc.max(p0.at(0), p1.at(0)) {
      let t = if p1.at(0) == p0.at(0) { 0 } else { (px - p0.at(0)) / (p1.at(0) - p0.at(0)) }
      return (
        x: px,
        y: p0.at(1) + (p1.at(1) - p0.at(1)) * t,
        dx: p1.at(0) - p0.at(0),
        dy: p1.at(1) - p0.at(1),
      )
    }
  }
  return none
}


// Renders annotations for a polyline given in screen space. Needs to be
// called in a context.
#let render-annotations(points, annotations, color, transform) = {
  if type(annotations) == dictionary { annotations = (annotations,) }

  for annotation in annotations {
    let anchor = find-anchor(points, annotation.at, transform)
    assert(
      anchor != none,
      message: "annotation: " + repr(annotation.at) + " is not on the curve"
    )
    let (x, y) = (anchor.x * 1pt, anchor.y * 1pt)
    let fill = if annotation.fill == auto { color } else { annotation.fill }
    let body = text(fill: fill, annotation.body)
    let follow = annotation.follow
    if follow == auto { follow = annotation.offset == none }

    let angle = if follow { calc.atan2(anchor.dx, anchor.dy) } else { 0deg }
    if angle > 90deg { angle -= 180deg } else if angle < -90deg { angle += 180deg }

    if annotation.offset == none {
      let alignment = if annotation.side == top { center + bottom } else { center + top }
      let body = if annotation.side == top {
        pad(bottom: annotation.gap, body)
      } else {
        pad(top: annotation.gap, body)
      }
      place(
        dx: x, dy: y,
        place(alignment, rotate(angle, origin: alignment, reflow: false, body))
      )
      continue
    }

    let (ox, oy) = annotation.offset.map(length => length.to-absolute())
    place(
      dx: x + ox, dy: y + oy,
      place(center + horizon, rotate(angle, reflow: false, body))
    )

    let leader = annotation.leader
    if leader == none { continue }

    // Start the leader at the edge of the content, not at its center.
    let size = measure(body)
    let inset = 2pt
    let scale = calc.min(
      if ox == 0pt { float.inf } else { (size.width / 2 + inset) / calc.abs(ox) },
      if oy == 0pt { float.inf } else { (size.height / 2 + inset) / calc.abs(oy) },
    )
    if scale >= 1 { continue }
    let start = (x + ox * (1 - scale), y + oy * (1 - scale))

    let tip = none
    let stroke = .5pt + color
    if type(leader) == function {
      tip = leader
    } else if leader != auto {
      stroke = leader
    }

    if tip == none {
      place(std.line(start: start, end: (x, y), stroke: stroke))
    } else {
      place(tiptoe.line(start: start, end: (x, y), stroke: stroke, tip: tip))
    }
  }
}
