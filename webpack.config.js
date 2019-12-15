const path = require("path");

const prod = process.env.NODE_ENV == "production";

// Set up production mode
let elm_loader_options = {};
if (prod) {
  elm_loader_options.optimize = true;
} else {
  elm_loader_options.debug = true;
}

module.exports = {
  entry: "./app/src/index.js",
  mode: prod ? "production" : "development",
  output: {
    path: path.resolve(__dirname, "static", "dist"),
    filename: "bundle.js",
  },
  module: {
    rules: [{
      test: /\.elm$/,
      exclude: [/elm-stuff/, /node_modules/],
      use: {
        loader: 'elm-webpack-loader',
        options: elm_loader_options,
      },
    }],
  },
};
