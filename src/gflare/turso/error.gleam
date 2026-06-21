pub type TursoError {
  ApiError(message: String)
  NotFound(name: String)
  Conflict(name: String)
  NetworkError(message: String)
  DecodeError(message: String)
}

pub fn to_string(error: TursoError) -> String {
  case error {
    ApiError(msg) -> "Turso API error: " <> msg
    NotFound(name) -> "Database not found: " <> name
    Conflict(name) -> "Database already exists: " <> name
    NetworkError(msg) -> "Network error: " <> msg
    DecodeError(msg) -> "Decode error: " <> msg
  }
}
