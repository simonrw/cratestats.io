import { Elm } from "./Main.elm";

let app = Elm.Main.init({
  node: document.querySelector("main"),
});

app.ports.elmToJs.subscribe(data => {
  let ids = data.ids;
  let traces = data.data;
  let layout = data.layout;
  let graph = data.graph;

  requestAnimationFrame(() => {
    // Start by plotting the history plot
    // Get rid of any existing plot
    let historyId = ids.history;
    Plotly.purge(historyId);
    Plotly.newPlot(historyId, traces, layout);

    // Then render the dependency graph
    let depId = ids.dependencies;
    renderGraph(`#${depId}`, graph);
  });
});

function renderGraph(id, graph) {
  const width = 960,
    height = 500,
    nodeRadius = 5;


  var cola = window.cola.d3adaptor(d3)
    .avoidOverlaps(true)
    .size([width, height]);

  const svg = d3.select(id).append("svg")
    .attr("width", width)
    .attr("height", height);


  cola
    .nodes(graph.nodes)
    .links(graph.links)
    .flowLayout("y", 30)
    .symmetricDiffLinkLengths(6)
    .start(10, 20, 20);

  var node = svg.selectAll(".node")
    .data(graph.nodes)
    .enter().append("circle")
    .attr("class", "node")
    .attr("r", 5)
    .on("click", function(d) {
      d.fixed = true;
    })
    .call(cola.drag)
  ;

  node.append("title")
    .text(function(d) { return d.name; });

  var link = svg.selectAll(".link")
    .data(graph.links)
    .enter().append("svg:path")
    .attr("class", "link")
  ;

  cola.on("tick", function () {
    // draw directed edges with proper padding from node centers
    link.attr('d', function (d) {
      var deltaX = d.target.x - d.source.x,
        deltaY = d.target.y - d.source.y,
        dist = Math.sqrt(deltaX * deltaX + deltaY * deltaY),
        normX = deltaX / dist,
        normY = deltaY / dist,
        sourcePadding = nodeRadius,
        targetPadding = nodeRadius + 2,
        sourceX = d.source.x + (sourcePadding * normX),
        sourceY = d.source.y + (sourcePadding * normY),
        targetX = d.target.x - (targetPadding * normX),
        targetY = d.target.y - (targetPadding * normY);
      return 'M' + sourceX + ',' + sourceY + 'L' + targetX + ',' + targetY;
    });

    node.attr("cx", function (d) { return d.x; })
      .attr("cy", function (d) { return d.y; });
  });
}
