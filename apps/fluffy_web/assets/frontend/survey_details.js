import { Elm } from './src/SurveyDetails.elm';

export function start_elm(flags) {
  const surveyId = window.location.pathname.split('/').filter(Boolean).pop();

  return Elm.SurveyDetails.init({
    node: document.getElementById("myapp"),
    flags: {
      ...flags,
      surveyId: surveyId
    }
  });
}