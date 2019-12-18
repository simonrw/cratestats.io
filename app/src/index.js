import { Elm } from "./Main.elm";

let app = Elm.Main.init({
  node: document.querySelector("main"),
});

app.ports.elmToJs.subscribe(data => {
  let id = data.id;
  let traces = data.data;
  let layout = data.layout;

  requestAnimationFrame(() => {
    // Get rid of any existing plot
    Plotly.purge(id);

    Plotly.newPlot(id, traces, layout);
  });
});
