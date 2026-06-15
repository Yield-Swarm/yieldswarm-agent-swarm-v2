import Map, { Marker } from "react-map-gl";
import "mapbox-gl/dist/mapbox-gl.css";

type Props = {
  lat: number;
  lng: number;
  onMove: (pos: { lat: number; lng: number }) => void;
};

const token = import.meta.env.VITE_MAPBOX_TOKEN as string | undefined;

export default function MapView({ lat, lng, onMove }: Props) {
  if (!token) {
    return (
      <div className="mapbox-fallback">
        <div>
          <p><strong>Mapbox tracking</strong></p>
          <p>Set <code>VITE_MAPBOX_TOKEN</code> to enable live map.</p>
          <p>Position: {lat.toFixed(4)}, {lng.toFixed(4)}</p>
          <button style={{ marginTop: 12, width: "auto", padding: "8px 16px" }}
            onClick={() => onMove({ lat: lat + 0.001, lng: lng + 0.001 })}>
            Simulate movement
          </button>
        </div>
      </div>
    );
  }

  return (
    <Map
      mapboxAccessToken={token}
      initialViewState={{ latitude: lat, longitude: lng, zoom: 12 }}
      style={{ width: "100%", height: "100%", minHeight: 400 }}
      mapStyle="mapbox://styles/mapbox/dark-v11"
      onMoveEnd={(e) => onMove({ lat: e.viewState.latitude, lng: e.viewState.longitude })}
    >
      <Marker latitude={lat} longitude={lng} color="#00d4aa" />
    </Map>
  );
}
