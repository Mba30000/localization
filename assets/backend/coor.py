import sqlite3
import math

def create_rtree_from_locations():
    """Creates the location_rtree table from the locations table and populates it."""
    conn = sqlite3.connect('location.db')
    cursor = conn.cursor()

    # Drop old rtree if it exists
    cursor.execute("DROP TABLE IF EXISTS location_rtree")

    # Create the new location_rtree table
    cursor.execute('''
        CREATE TABLE location_rtree (
            Grid_x INTEGER,
            Grid_y INTEGER,
            min_lat REAL,
            min_lon REAL,
            swap_needed INTEGER DEFAULT 0
        )
    ''')

    # Fetch data from the locations table
    cursor.execute("SELECT Grid_x, Grid_y, Estimated_Latitude, Estimated_Longitude FROM locations")
    rows = cursor.fetchall()

    for grid_x, grid_y, latitude, longitude in rows:
        # Determine if swap is needed (example condition: x > y)
        swap_needed = 1 if grid_x > grid_y else 0

        # Swap values if necessary
        if swap_needed:
            grid_x, grid_y = grid_y, grid_x

        # Insert into rtree
        cursor.execute('''
            INSERT INTO location_rtree (Grid_x, Grid_y, min_lat, min_lon, swap_needed)
            VALUES (?, ?, ?, ?, ?)
        ''', (grid_x, grid_y, latitude, longitude, swap_needed))

    conn.commit()
    conn.close()
    print("location_rtree table created and populated.")

def haversine(lat1, lon1, lat2, lon2):
    """Calculate the great-circle distance using the Haversine formula."""
    R = 6371  # Earth radius in km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)

    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    return R * c  # Distance in km

def find_nearest_grid(latitude, longitude):
    """Find the nearest grid point using an optimized SQLite query."""
    conn = sqlite3.connect('location.db')
    cursor = conn.cursor()

    cursor.execute('''
        SELECT Grid_x, Grid_y, min_lat, min_lon, swap_needed
        FROM location_rtree
        ORDER BY ABS(min_lat - ?) + ABS(min_lon - ?) 
        LIMIT 10  -- Narrow search space before exact Haversine calculation
    ''', (latitude, longitude))

    grids = cursor.fetchall()
    nearest_grid = None
    min_distance = float('inf')

    for grid_x, grid_y, grid_lat, grid_lon, swap_needed in grids:
        if swap_needed == 1:
            grid_x, grid_y = grid_y, grid_x
        
        distance = haversine(latitude, longitude, grid_lat, grid_lon)
        
        if distance < min_distance:
            min_distance = distance
            nearest_grid = (grid_x, grid_y)

    conn.close()

    if nearest_grid:
        print(f"Nearest grid coordinates for ({latitude}, {longitude}): x = {nearest_grid[0]}, y = {nearest_grid[1]}")
    else:
        print(f"No match found for ({latitude}, {longitude})")

# Create the R-Tree structure
create_rtree_from_locations()

# Test with GPS coordinates
find_nearest_grid(21.4948874, 39.2449802)
find_nearest_grid(21.4951763, 39.244543)
find_nearest_grid(21.4950652, 39.2449167)
find_nearest_grid(21.495926, 39.2454459)
find_nearest_grid(21.4957163, 39.2450928)
