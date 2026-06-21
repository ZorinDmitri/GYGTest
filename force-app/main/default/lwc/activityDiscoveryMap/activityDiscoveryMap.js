import { LightningElement, track, wire } from "lwc";
import { loadScript, loadStyle } from "lightning/platformResourceLoader";
import LEAFLET from "@salesforce/resourceUrl/leaflet";

import searchByCity from "@salesforce/apex/ActivityDiscoveryMapController.searchByCity";
import searchByRadius from "@salesforce/apex/ActivityDiscoveryMapController.searchByRadius";
import getFilterOptions from "@salesforce/apex/ActivityDiscoveryMapController.getFilterOptions";

const SEARCH_MODE = { CITY: "city", RADIUS: "radius" };

const CATEGORY_COLOURS = {
  Sightseeing: "#E63946",
  "History & Culture": "#E76F51",
  "Food & Drink": "#F4A261",
  "Outdoor & Adventure": "#2A9D8F",
  Family: "#457B9D",
  Nightlife: "#6A0572",
  _default: "#888888"
};

const DEFAULT_RADIUS_KM = 25;
const MAP_DEFAULT_CENTER = [48.8566, 2.3522];
const MAP_DEFAULT_ZOOM = 3;
const MAP_RESULT_ZOOM = 12;

// ─── Component ────────────────────────────────────────────────────────────────

export default class ActivityDiscoveryMap extends LightningElement {
  searchMode = SEARCH_MODE.CITY;
  cityInput = "";
  latInput = "";
  lngInput = "";
  radiusInput = String(DEFAULT_RADIUS_KM);

  selectedCategory = "";
  selectedGoodFor = "";

  categories = [];
  goodForOptions = [];

  @track activities = [];
  isCapped = false;
  isLoading = false;
  hasSearched = false;
  errorMessage = "";

  _leafletLoaded = false;
  _map = null;
  _markerLayer = null;
  _markerMap = {};
  _selectedId = null;

  renderedCallback() {
    if (this._leafletLoaded) return;
    this._leafletLoaded = true;

    Promise.all([
      loadStyle(this, LEAFLET + "/leaflet/leaflet.css"),
      loadScript(this, LEAFLET + "/leaflet/leaflet.js")
    ])
      .then(() => {
        this._L = window.L;
        if (!this._L) {
          throw new Error("Leaflet loaded but window.L is undefined.");
        }
        this._fixLeafletIcons();
        this._initMap();
      })
      .catch((err) => {
        console.error(
          "Leaflet failed to load — full error:",
          JSON.stringify(err)
        );
        console.error("Leaflet failed to load — raw:", err);
        console.error("LEAFLET resource URL:", LEAFLET);
        this.errorMessage =
          "Map library failed to load. Please refresh the page.";
      });
  }

  @wire(getFilterOptions)
  wiredFilterOptions({ data, error }) {
    if (data) {
      this.categories = data.categories || [];
      this.goodForOptions = data.goodForOptions || [];
    } else if (error) {
      console.error("getFilterOptions error", error);
    }
  }

  _initMap() {
    const container = this.refs.mapContainer;
    if (!container) return;

    this._map = this._L.map(container, {
      center: MAP_DEFAULT_CENTER,
      zoom: MAP_DEFAULT_ZOOM
    });

    this._L
      .tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 19,
        attribution:
          '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
      })
      .addTo(this._map);

    this._markerLayer = this._L.layerGroup().addTo(this._map);
  }

  _fixLeafletIcons() {
    delete this._L.Icon.Default.prototype._getIconUrl;
    this._L.Icon.Default.mergeOptions({
      iconUrl: LEAFLET + "/leaflet/images/marker-icon.png",
      iconRetinaUrl: LEAFLET + "/leaflet/images/marker-icon-2x.png",
      shadowUrl: LEAFLET + "/leaflet/images/marker-shadow.png"
    });
  }

  handleModeSwitch(evt) {
    this.searchMode = evt.currentTarget.dataset.mode;
    this.errorMessage = "";
  }

  handleCityInput(evt) {
    this.cityInput = evt.target.value;
  }
  handleLatInput(evt) {
    this.latInput = evt.target.value;
  }
  handleLngInput(evt) {
    this.lngInput = evt.target.value;
  }
  handleRadiusInput(evt) {
    this.radiusInput = evt.target.value;
  }

  handleCityKeydown(evt) {
    if (evt.key === "Enter") this.handleSearch();
  }

  handleCategoryChange(evt) {
    this.selectedCategory = evt.target.value;
    if (this.hasSearched) this.handleSearch();
  }

  handleGoodForChange(evt) {
    this.selectedGoodFor = evt.target.value;
    if (this.hasSearched) this.handleSearch();
  }

  handleSearch() {
    this.errorMessage = "";

    if (this.searchMode === SEARCH_MODE.RADIUS) {
      const lat = parseFloat(this.latInput);
      const lng = parseFloat(this.lngInput);
      const radius = parseFloat(this.radiusInput);

      if (isNaN(lat) || isNaN(lng)) {
        this.errorMessage = "Please enter valid latitude and longitude values.";
        return;
      }
      if (isNaN(radius) || radius <= 0) {
        this.errorMessage = "Please enter a positive radius in km.";
        return;
      }
    }

    if (this.searchMode === SEARCH_MODE.CITY) {
      const cityEl = this.template.querySelector(".search-input");
      if (cityEl) this.cityInput = cityEl.value;
    }

    this.isLoading = true;
    this.hasSearched = true;

    const promise =
      this.searchMode === SEARCH_MODE.CITY
        ? searchByCity({
            city: this.cityInput,
            category: this.selectedCategory || null,
            goodFor: this.selectedGoodFor || null
          })
        : searchByRadius({
            // Parse here — values are validated just above.
            centerLat: parseFloat(this.latInput),
            centerLng: parseFloat(this.lngInput),
            radiusKm: parseFloat(this.radiusInput),
            category: this.selectedCategory || null,
            goodFor: this.selectedGoodFor || null
          });

    promise
      .then((result) => {
        this.isCapped = result.capped;
        this.activities = this._enrichActivities(result.activities);
        this._renderMarkers(result.activities);
      })
      .catch((err) => {
        console.error(
          "ActivityDiscoveryMap search error:",
          JSON.stringify(err)
        );
        this.errorMessage =
          err?.body?.message ||
          err?.message ||
          "An unexpected error occurred. Check browser console for details.";
        this.activities = [];
        this._clearMarkers();
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleListItemClick(evt) {
    const id = evt.currentTarget.dataset.id;
    this._selectActivity(id);
    const marker = this._markerMap[id];
    if (marker && this._map) {
      this._map.panTo(marker.getLatLng(), { animate: true });
      marker.openPopup();
    }
  }

  handleListItemKeydown(evt) {
    if (evt.key === "Enter" || evt.key === " ") {
      evt.preventDefault();
      this.handleListItemClick(evt);
    }
  }

  _selectActivity(id) {
    this._selectedId = id;
    this.activities = this.activities.map((a) => ({
      ...a,
      listItemClass: this._listItemClass(a.id)
    }));
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      const el = this.template.querySelector(`[data-id="${id}"]`);
      if (el) el.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }, 0);
  }

  _renderMarkers(rawActivities) {
    this._clearMarkers();
    const bounds = [];

    rawActivities.forEach((a) => {
      if (!a.latitude || !a.longitude) return;

      const colour =
        CATEGORY_COLOURS[a.category] || CATEGORY_COLOURS["_default"];
      const latlng = [a.latitude, a.longitude];

      const marker = this._L.circleMarker(latlng, {
        radius: 9,
        fillColor: colour,
        color: "#fff",
        weight: 2,
        opacity: 1,
        fillOpacity: 0.9
      });

      marker.bindPopup(this._buildPopupHtml(a), { maxWidth: 260 });
      marker.on("click", () => {
        this._selectActivity(a.id);
        this._scrollListItemIntoView(a.id);
      });

      marker.addTo(this._markerLayer);
      this._markerMap[a.id] = marker;
      bounds.push(latlng);
    });

    if (bounds.length > 0 && this._map) {
      if (bounds.length === 1) {
        this._map.setView(bounds[0], MAP_RESULT_ZOOM);
      } else {
        this._map.fitBounds(this._L.latLngBounds(bounds), {
          padding: [40, 40]
        });
      }
    }
  }

  _clearMarkers() {
    if (this._markerLayer) this._markerLayer.clearLayers();
    this._markerMap = {};
    this._selectedId = null;
  }

  _buildPopupHtml(activity) {
    const colour =
      CATEGORY_COLOURS[activity.category] || CATEGORY_COLOURS["_default"];
    const summary = activity.listingSummary
      ? `<p style="margin:4px 0 0;font-size:12px;color:#555">${activity.listingSummary}</p>`
      : "";
    const cat = activity.category
      ? `<span style="display:inline-block;background:${colour};color:#fff;border-radius:3px;padding:1px 6px;font-size:11px;margin-top:4px">${activity.category}</span>`
      : "";
    return `
      <div style="font-family:sans-serif;min-width:160px">
        <strong style="font-size:13px">${activity.name}</strong>
        ${cat}
        ${summary}
        <p style="margin:4px 0 0;font-size:11px;color:#888">${activity.city || ""}, ${activity.country || ""}</p>
      </div>`;
  }

  _scrollListItemIntoView(id) {
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      const el = this.template.querySelector(`[data-id="${id}"]`);
      if (el) el.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }, 0);
  }

  _enrichActivities(rawActivities) {
    return rawActivities.map((a) => ({
      ...a,
      listItemClass: this._listItemClass(a.id),
      dotStyle: `background-color: ${CATEGORY_COLOURS[a.category] || CATEGORY_COLOURS["_default"]}`
    }));
  }

  _listItemClass(id) {
    return (
      "activity-list__item" +
      (id === this._selectedId ? " activity-list__item--selected" : "")
    );
  }

  get isCityMode() {
    return this.searchMode === SEARCH_MODE.CITY;
  }
  get isRadiusMode() {
    return this.searchMode === SEARCH_MODE.RADIUS;
  }

  get cityModeClass() {
    return "toggle-btn" + (this.isCityMode ? " toggle-btn--active" : "");
  }
  get radiusModeClass() {
    return "toggle-btn" + (this.isRadiusMode ? " toggle-btn--active" : "");
  }

  get hasResults() {
    return this.activities.length > 0;
  }
  get hasError() {
    return !!this.errorMessage && !this.isLoading;
  }
  get showEmpty() {
    return (
      this.hasSearched && !this.isLoading && !this.hasError && !this.hasResults
    );
  }
  get showPreSearch() {
    return !this.hasSearched && !this.isLoading;
  }

  get resultCountLabel() {
    const n = this.activities.length;
    return `${n} activit${n === 1 ? "y" : "ies"}${this.isCapped ? " (capped at 200)" : ""}`;
  }
}
