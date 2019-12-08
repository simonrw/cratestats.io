import { Elm } from "./Main.elm";

let app = Elm.Main.init({
  node: document.querySelector("main"),
});

app.ports.showDownloadsByVersion.subscribe(data => {
  const plotElem = document.getElementById("plot-space");
  console.log("Plotting");

  let plotData = [
    // Headings and the nature of additional parameters
    ['Version', 'Downloads'],
  ];

  for (var downloadVersion of data) {
    plotData.push([downloadVersion.version, downloadVersion.downloads]);
  }

  let myData = window.google.visualization.arrayToDataTable(plotData);
  let options = {};

  let chart = new window.google.visualization.BarChart(plotElem);
  chart.draw(myData, options);
});
