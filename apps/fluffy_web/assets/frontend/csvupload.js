import { Elm } from './src/CsvUpload.elm';
export function start_elm(flags) {
  return Elm.CsvUpload.init({
    node: document.getElementById("myapp"),
    flags: flags
  });
};