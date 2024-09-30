import { Elm } from './src/AllSurveys.elm';
export function start_elm(flags) {
  return Elm.AllSurveys.init({
    node: document.getElementById("myapp"),
    flags: flags
  });
};