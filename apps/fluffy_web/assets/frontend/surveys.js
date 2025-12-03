import { Elm } from './src/Surveys.elm';
export function start_elm(flags) {
  const app = Elm.Surveys.init({
    node: document.getElementById("myapp"),
    flags: flags
  });

  if (app.ports.downloadCsvPort) {
    app.ports.downloadCsvPort.subscribe((url) => {
      const a = document.createElement("a");
      a.href = url;
      a.target = "_blank";
      a.download = "";
      a.click();
    });
  }

  return app;
};