export function startMapPicker(elmApp) {
  window.pickLocation = function (currentLat = null, currentLng = null, nearbyPoints = []) {
    const mapWindow = window.open("", "MapPicker", "width=800,height=600");

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
          function initMap(lat, lng) {
            const map = L.map('leaflet-map').setView([lat, lng], 15);

            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
              maxZoom: 19,
              attribution: '© OpenStreetMap'
            }).addTo(map);

            // Main marker (draggable)
            const marker = L.marker([lat, lng], { draggable: true }).addTo(map);

            // Add nearby points
            const nearby = ${JSON.stringify(nearbyPoints)};
            nearby.forEach(p => {
              L.marker([p.lat, p.lng], {
                icon: L.icon({
                  iconUrl: 'https://maps.google.com/mapfiles/ms/icons/green-dot.png',
                  iconSize: [32, 32],
                  iconAnchor: [16, 32]
                })
              }).addTo(map);
            });

            // Send location when marker dragged
            marker.on('dragend', function (e) {
              const pos = e.target.getLatLng();
              window.opener.postMessage({ lat: pos.lat, lng: pos.lng }, "*");
              window.close();
            });

            // Send location when map clicked
            map.on('click', function (e) {
              marker.setLatLng(e.latlng);
              window.opener.postMessage({ lat: e.latlng.lat, lng: e.latlng.lng }, "*");
              window.close();
            });
          }

          // Use current location if none provided
          if (${currentLat} === null || ${currentLng} === null) {
            navigator.geolocation.getCurrentPosition(
              pos => initMap(pos.coords.latitude, pos.coords.longitude),
              err => initMap(0, 0) // fallback if geolocation denied
            );
          } else {
            initMap(${currentLat}, ${currentLng});
          }
        <\/script>
      </body>
      </html>
    `);
    window.addEventListener("message", (event) => {
      if (event.data && event.data.lat && event.data.lng) {
        const coords = event.data.lat + ", " + event.data.lng;
        elmApp.ports.receiveLocationPort.send(coords);
      }
    }, { once: true });
  };
}
