import { Elm } from "./Main.elm";

let app = Elm.Main.init({
  node: document.querySelector("main"),
});

app.ports.elmToJs.subscribe(data => {
  let elemId = data.id;
  let specs = data.specs;
  console.log(elemId, specs);

  requestAnimationFrame(() => {
    vegaEmbed(elemId, specs, {actions: false}).catch(console.error);
  });
});
