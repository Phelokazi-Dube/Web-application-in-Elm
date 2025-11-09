export function startMapPicker(elmApp) {
  window.pickLocation = function () {
    const mapWindow = window.open("", "MapPicker", "width=600,height=600");
    mapWindow.document.write(`
      <html>
      <head>
        <title>Pick a Location</title>
        <link
          rel="stylesheet"
          href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
        />
        <style>
          html, body, #leaflet-map {
            height: 100%;
            margin: 0;
          }
        </style>
      </head>
      <body>
        <div id="leaflet-map"></div>
        <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
        <script>
          navigator.geolocation.getCurrentPosition(position => {
            const { latitude, longitude } = position.coords;
            const map = L.map('leaflet-map').setView([latitude, longitude], 15);
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
              maxZoom: 19,
              attribution: '© OpenStreetMap'
            }).addTo(map);

            const marker = L.marker([latitude, longitude]).addTo(map);

            map.on('click', function (e) {
              const { lat, lng } = e.latlng;
              marker.setLatLng([lat, lng]);
              window.opener.postMessage({ lat, lng }, "*");
              window.close(); // close the popup after picking
            });
          });
        <\/script>
      </body>
      </html>
    `);
    window.addEventListener("message", (event) => {
      if (event.data && event.data.lat && event.data.lng) {
        const { lat, lng } = event.data;
        elmApp.ports.receiveLocationPort.send(`${lat}, ${lng}`);
      }
    }, { once: true });
  };
}