import { Elm } from './src/SurveyDetails.elm';

export function start_elm(flags) {
  const surveyId = window.location.pathname.split('/').filter(Boolean).pop();
  const returnTo = new URLSearchParams(window.location.search).get('return');
  let backUrl = '/combined';

  // Only allow a return URL on this application's combined-surveys page.
  if (returnTo) {
    try {
      const parsed = new URL(returnTo, window.location.origin);
      if (parsed.origin === window.location.origin && parsed.pathname === '/combined') {
        backUrl = parsed.pathname + parsed.search;
      }
    } catch (_) {
      // Invalid return parameter: use the default /combined link.
    }
  }

  return Elm.SurveyDetails.init({
    node: document.getElementById('myapp'),
    flags: {
      ...flags,
      surveyId,
      backUrl
    }
  });
}