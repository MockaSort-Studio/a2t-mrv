// Renders project boundaries (a GeoJSON FeatureCollection in data-projects)
// as polygons over OpenStreetMap tiles. Polygon-only — no markers.
import * as L from "../../vendor/leaflet.js"

export default {
  mounted() { this.render() },
  updated() { this.render() },
  render() {
    if (!this.map) {
      this.map = L.map(this.el).setView([0, 0], 2)
      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 19,
        attribution: "© OpenStreetMap contributors",
      }).addTo(this.map)
      this.layer = L.geoJSON().addTo(this.map)
    }
    this.layer.clearLayers()
    const collection = JSON.parse(this.el.dataset.projects || '{"type":"FeatureCollection","features":[]}')
    if (collection.features.length > 0) {
      this.layer.addData(collection)
      this.map.fitBounds(this.layer.getBounds(), {padding: [20, 20]})
    }
  },
}
