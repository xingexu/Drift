const path = require("path");
const CopyPlugin = require("copy-webpack-plugin");
const HtmlWebpackPlugin = require("html-webpack-plugin");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");

module.exports = {
  entry: {
    background: "./src/extension/background.ts",
    popup: "./src/extension/popup.ts",
    dashboard: "./src/ui/dashboard.ts",
    settings: "./src/ui/settings.ts",
  },
  output: {
    path: path.resolve(__dirname, "dist"),
    filename: "[name].js",
    clean: true,
  },
  resolve: {
    extensions: [".ts", ".js"],
  },
  module: {
    rules: [
      {
        test: /\.ts$/,
        use: "ts-loader",
        exclude: /node_modules/,
      },
      {
        test: /\.css$/,
        use: [MiniCssExtractPlugin.loader, "css-loader"],
      },
    ],
  },
  plugins: [
    new MiniCssExtractPlugin({ filename: "[name].css" }),
    new CopyPlugin({
      patterns: [
        { from: "public/manifest.json", to: "manifest.json" },
        { from: "public/icons", to: "icons", noErrorOnMissing: true },
        { from: "public/privacy.html", to: "privacy.html" },
      ],
    }),
    new HtmlWebpackPlugin({
      template: "./src/ui/popup.html",
      filename: "popup.html",
      chunks: ["popup"],
    }),
    new HtmlWebpackPlugin({
      template: "./src/ui/dashboard.html",
      filename: "dashboard.html",
      chunks: ["dashboard"],
    }),
    new HtmlWebpackPlugin({
      template: "./src/ui/settings.html",
      filename: "settings.html",
      chunks: ["settings"],
    }),
  ],
  optimization: {
    splitChunks: false,
  },
  devtool: "cheap-module-source-map",
};
