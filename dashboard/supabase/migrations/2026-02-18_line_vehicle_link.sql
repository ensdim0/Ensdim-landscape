-- Link geographic_lines to vehicles
ALTER TABLE geographic_lines
ADD COLUMN vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL;

CREATE INDEX idx_geographic_lines_vehicle_id ON geographic_lines(vehicle_id);
