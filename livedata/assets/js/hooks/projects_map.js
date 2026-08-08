// Renders parcel boundaries (a GeoJSON FeatureCollection in data-projects,
// one feature per parcel) as polygons over OpenStreetMap tiles. Polygon-only —
// no markers.
//
// The map is paired with the project list beside it: clicking a parcel selects
// its project in the LiveView, and a selection made in the list is pushed back
// here as a "highlight_project" event.
import * as L from "../../vendor/leaflet.js"

const BASE_STYLE = {color: "#3f3f46", weight: 2, fillOpacity: 0.15}
const HIGHLIGHT_STYLE = {color: "#b45309", weight: 3, fillOpacity: 0.35}

export default {
  mounted() {
    this.render()
    this.handleEvent("highlight_project", ({project_id}) => this.highlight(project_id))
  },
  updated() { this.render() },
  render() {
    if (!this.map) {
      this.map = L.map(this.el).setView([0, 0], 2)
      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 19,
        attribution: "© OpenStreetMap contributors",
      }).addTo(this.map)
      this.layer = L.geoJSON(null, {
        style: BASE_STYLE,
        onEachFeature: (feature, layer) => {
          const {project_id, name, parcel_ref} = feature.properties || {}
          layer.bindTooltip(`${name} — ${parcel_ref}`)
          layer.on("click", () => {
            this.highlight(project_id)
            this.pushEvent("map_selected_project", {project_id: project_id})
          })
        },
      }).addTo(this.map)
    }
    this.layer.clearLayers()
    const collection = JSON.parse(this.el.dataset.projects || '{"type":"FeatureCollection","features":[]}')
    if (collection.features.length > 0) {
      this.layer.addData(collection)
      this.map.fitBounds(this.layer.getBounds(), {padding: [20, 20]})
    }
  },
  // Repaints every parcel, then zooms to the selected project's parcels.
  highlight(projectId) {
    const selected = []
    this.layer.eachLayer((layer) => {
      const match = layer.feature && layer.feature.properties.project_id === projectId
      layer.setStyle(match ? HIGHLIGHT_STYLE : BASE_STYLE)
      if (match) { selected.push(layer) }
    })
    if (selected.length > 0) {
      this.map.fitBounds(L.featureGroup(selected).getBounds(), {padding: [20, 20]})
    }
  },
}
