// Модели состояния игры — единый снимок, обновляется парсером.

class CarData {
  // motion
  double? x, z, yaw;
  // participant
  String name = "";
  int teamId = -1;
  int raceNumber = 0;
  bool active = false;
  // lap
  int position = 0;
  double lapDistance = 0;
  int lastLapMs = 0;
  int deltaLeaderMs = 0;
  int deltaFrontMs = 0;
  int resultStatus = 0;
  // status
  int visualCompound = 0;
  int tyreAge = 0;
}

class PlayerData {
  int speed = 0, gear = 0, rpm = 0, drs = 0, drsAllowed = 0, revLights = 0;
  double throttle = 0, brake = 0, steer = 0;
  List<int> tyreSurfaceTemp = [0, 0, 0, 0];
  List<double> tyrePressure = [0, 0, 0, 0];
  List<double> tyreWear = [0, 0, 0, 0];
  int compound = 0, tyreAge = 0, ersMode = 0;
  double ersStore = 0, fuelLaps = 0;
  int fiaFlag = 0;
  int curLapMs = 0, lastLapMs = 0, s1 = 0, s2 = 0;
  int sector = 0, position = 0, curLapNum = 0;
  int deltaLeaderMs = 0, deltaFrontMs = 0, lapInvalid = 0;
}

class SessionData {
  int weather = -1, trackId = -1, sessionType = -1;
  int trackTemp = 0, airTemp = 0, totalLaps = 0, trackLength = 0;
  List<MarshalZone> marshalZones = [];
}

class MarshalZone {
  final double start;
  final int flag;
  MarshalZone(this.start, this.flag);
}

class GameEvent {
  final String text;
  final DateTime t;
  GameEvent(this.text) : t = DateTime.now();
}

class GameState {
  int playerIndex = 0;
  SessionData session = SessionData();
  List<CarData> cars = List.generate(22, (_) => CarData());
  PlayerData player = PlayerData();
  List<GameEvent> events = [];
  Map<int, List<int>> history = {}; // carIdx -> lap times ms

  void pushEvent(String text) {
    events.add(GameEvent(text));
    if (events.length > 12) events.removeAt(0);
  }

  int get safePlayerIndex =>
      (playerIndex >= 0 && playerIndex < 22) ? playerIndex : 0;
}
