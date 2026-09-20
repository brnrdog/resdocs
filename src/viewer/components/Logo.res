/* The resdocs mark: the ReScript tile with an open book where its
   letter sits. Same rounded square and red as the ReScript logo, so
   the two read as a family without copying the letterform. */

open Xote

let make = (~size: int=28, ~attrs: array<(string, View.attrValue)>=[]): View.node => {
  let px = Int.toString(size)
  View.element(
    "svg",
    ~attrs=Array.concat(
      [
        View.attr("width", px),
        View.attr("height", px),
        View.attr("viewBox", "0 0 32 32"),
        View.attr("fill", "none"),
        View.attr("aria-hidden", "true"),
        View.attr("class", "logo"),
      ],
      attrs,
    ),
    ~children=[
      View.element(
        "rect",
        ~attrs=[
          View.attr("x", "0"),
          View.attr("y", "0"),
          View.attr("width", "32"),
          View.attr("height", "32"),
          View.attr("rx", "7"),
          View.attr("fill", "currentColor"),
        ],
        (),
      ),
      /* Spine */
      View.element(
        "path",
        ~attrs=[
          View.attr("d", "M16 9.6v14.4"),
          View.attr("stroke", "#fff"),
          View.attr("stroke-width", "2"),
          View.attr("stroke-linecap", "round"),
        ],
        (),
      ),
      /* The two open pages */
      View.element(
        "path",
        ~attrs=[
          View.attr(
            "d",
            "M16 9.6C13.9 8.2 11.4 7.6 8.4 7.9c-.8.1-1.4.8-1.4 1.6v11.8c0 .9.8 1.7 1.7 1.6 2.7-.2 5 .3 6.9 1.5M16 9.6c2.1-1.4 4.6-2 7.6-1.7.8.1 1.4.8 1.4 1.6v11.8c0 .9-.8 1.7-1.7 1.6-2.7-.2-5 .3-6.9 1.5",
          ),
          View.attr("stroke", "#fff"),
          View.attr("stroke-width", "2"),
          View.attr("stroke-linejoin", "round"),
          View.attr("stroke-linecap", "round"),
        ],
        (),
      ),
    ],
    (),
  )
}
