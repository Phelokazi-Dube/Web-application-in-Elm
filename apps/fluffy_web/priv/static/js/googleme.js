const app = start_elm(null);
app.ports.signIn.subscribe(() => {
  console.log("Received click.");
  authenticate(true);
});

window.google.accounts.id.initialize({
  client_id: '1083959778576-iakboe5jsa216o17klhtqeenqg1vec92.apps.googleusercontent.com',
  ux_mode: 'redirect', // This sets the redirect mode
  redirect_uri: 'http://localhost:8000', // Replace this with your actual redirect URI if you're not using elm reactor
});

// function authenticate(immediate) {
//   window.google.accounts.id.prompt({
//     auto_select: immediate,
//     prompt_parent_id: 'myapp',
//   });
// }

/*
BEFORE this is loaded, I must load api.js.
AFTER this is loaded, I must load gsi/client.
*/

const CLIENT_ID = '1083959778576-iakboe5jsa216o17klhtqeenqg1vec92.apps.googleusercontent.com'; 
var allReady = false;
var popup_error = false;
const initialTokenClientConfig = {
  client_id: CLIENT_ID,
  scope: 'profile email',
  callback: (response) => {
    popup_error = false;
    console.log(response);
    if (response && response.access_token) {
      let granted = google.accounts.oauth2.hasGrantedAllScopes(response, 'profile', 'email');
      console.log(`Auth Granted: ${granted}`);
      if (granted) {
        console.log('Loading GAPI client');
        gapi.load('client', {
          callback: function() {
            console.log('GAPI client loaded.  Setting authentication token.');
            gapi.client.setToken({ access_token: response.access_token });
            allReady = true;
            app.ports.signedIn.send(true);
            setTimeout(() => {
              console.log(`${new Date(Date.now()).toString()} Token has expired.  Marking re-request as necessary.`);
              allReady = false;
            }, 1000 * (response.expires_in - 10));
        },
          onerror: function() {
            console.log('FATAL: Error loading GAPI client for API');
          }
        });
      } else {
        console.log('Auth not granted.  Re-requesting.');
        client.requestAccessToken();
      }
    }
  },
  error_callback: (e) => {
    popup_error = true;
    if (e.type === 'popup_closed') {
      alert('You closed the sign-in window.  Please click on the button to start the sign-in process again.');
    } else if (e.type === 'popup_failed_to_open') {
      alert('I couldn\'t open the sign-in window.  Please allow popups for this site.');
    } else {
      console.log(e);
    }
  }
};
const client = google.accounts.oauth2.initTokenClient(initialTokenClientConfig);

// GAPI

var counter = 0;
function authenticate(userInteracted) {
  if (allReady != true) {
    // TODO: put up a spinner!
    console.log("Not ready yet... waiting.");
    if (counter == 0 || userInteracted) {
      console.log("Requesting access token");
      counter = 0;
      client.requestAccessToken();
    }
    counter++;
    if (popup_error) {
      counter = 0;
      return; // do not retry this function.
    }
    setTimeout(() => authenticate(docJson, false), 1000);
    return;
  }
  counter = 0;
}