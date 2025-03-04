class GridLocation {
  double x;
  double y;
  int floor;

  GridLocation({this.x = 0.0, this.y = 0.0, this.floor = 1});

  @override
  String toString() => "($x, $y) floor $floor";
}