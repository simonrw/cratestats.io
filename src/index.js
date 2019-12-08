import { Elm } from "./Main.elm";

let app = Elm.Main.init({
  node: document.querySelector("main"),
});

app.ports.showDownloadsByVersion.subscribe(data => {
  let elemId = data.id;
  let crateDetails = data.crate;

  // Run this in requestAnimationFrame so that we can be sure the plot element (created by Elm) exists
  // https://stackoverflow.com/a/42451273/56711
  requestAnimationFrame(() => {
    if (document.getElementById(elemId) === null) {
      console.error("cannot find plot element");
      return;
    }

    let x = [];
    let y = [];

    for (var downloadVersion of crateDetails) {
      x.push(downloadVersion.version);
      y.push(downloadVersion.downloads);
    }

    let plotData = [
      {
        x: x,
        y: y,
        type: "bar",
      },
    ];

    window.Plotly.newPlot(elemId, plotData);
  });
});
