class CoordinateMapper:
    # Coefficients for X
    a = -152849851.68223003  # lat^2 coefficient
    b = 690833799.8838825    # lon^2 coefficient
    c = 4507346.173552647    # lat * lon coefficient
    d = -1042662.6944415867  # lat coefficient
    e = -8515450.678935528   # lon coefficient
    f = -11914014509.537245  # constant term for X

    # Coefficients for Y
    g = -50313304.201427646  # lat^2 coefficient for Y
    h = 51356736.02332509    # lon^2 coefficient for Y
    i = -1789493.3150535524  # lat * lon coefficient for Y
    j = 3243105.721315112    # lat coefficient for Y
    k = -1542578.3709250167  # lon coefficient for Y
    l = -467159893.2855754   # constant term for Y

    @staticmethod
    def lat_lon_to_xy(lat, lon):
        x = (CoordinateMapper.a * lat**2 +
             CoordinateMapper.b * lon**2 +
             CoordinateMapper.c * lat * lon +
             CoordinateMapper.d * lat +
             CoordinateMapper.e * lon +
             CoordinateMapper.f)
        
        y = (CoordinateMapper.g * lat**2 +
             CoordinateMapper.h * lon**2 +
             CoordinateMapper.i * lat * lon +
             CoordinateMapper.j * lat +
             CoordinateMapper.k * lon +
             CoordinateMapper.l)

        return x, y  # Returns tuple (X, Y)


# Example usage
latitude = 21.494708
longitude = 39.2448436
x, y = CoordinateMapper.lat_lon_to_xy(latitude, longitude)

print(f"Mapped Grid Coordinates: X = {x}, Y = {y}")
