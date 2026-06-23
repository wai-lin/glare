pub type GleamType {
  GInt
  GFloat
  GString
  GBool
  GBitArray
  GOption(GleamType)
  GDate
  GTime
  GTimestamp
  GUuid
  GJson
}

pub type QueryParam {
  QueryParam(name: String, gleam_type: GleamType)
}

pub type ResultSet {
  ResultSet(name: String, gleam_type: GleamType)
}

pub type ParsedQuery {
  ParsedQuery(
    name: String,
    params: List(QueryParam),
    returns: List(ResultSet),
    sql: String,
    backends: List(DbBackend),
  )
}

pub type DbBackend {
  D1
  Turso
  Both
}

pub fn gleam_type_to_string(t: GleamType) -> String {
  case t {
    GInt -> "Int"
    GFloat -> "Float"
    GString -> "String"
    GBool -> "Bool"
    GBitArray -> "BitArray"
    GOption(inner) -> "Option(" <> gleam_type_to_string(inner) <> ")"
    GDate -> "String"
    GTime -> "String"
    GTimestamp -> "String"
    GUuid -> "String"
    GJson -> "String"
  }
}

pub fn parse_gleam_type(s: String) -> Result(GleamType, String) {
  case s {
    "Int" -> Ok(GInt)
    "Float" -> Ok(GFloat)
    "String" -> Ok(GString)
    "Bool" -> Ok(GBool)
    "BitArray" -> Ok(GBitArray)
    "Option(Int)" -> Ok(GOption(GInt))
    "Option(Float)" -> Ok(GOption(GFloat))
    "Option(String)" -> Ok(GOption(GString))
    "Option(Bool)" -> Ok(GOption(GBool))
    "Option(BitArray)" -> Ok(GOption(GBitArray))
    "Date" -> Ok(GDate)
    "Time" -> Ok(GTime)
    "Timestamp" -> Ok(GTimestamp)
    "Uuid" -> Ok(GUuid)
    "Json" -> Ok(GJson)
    "Option(Date)" -> Ok(GOption(GDate))
    "Option(Time)" -> Ok(GOption(GTime))
    "Option(Timestamp)" -> Ok(GOption(GTimestamp))
    "Option(Uuid)" -> Ok(GOption(GUuid))
    "Option(Json)" -> Ok(GOption(GJson))
    _ ->
      Error(
        "Unknown type: "
        <> s
        <> ". Expected one of: Int, Float, String, Bool, BitArray, Date, Time, Timestamp, Uuid, Json, or Option(T)",
      )
  }
}

pub fn gleam_type_to_decoder(t: GleamType) -> String {
  case t {
    GInt -> "decode.int"
    GFloat -> "decode.float"
    GString -> "decode.string"
    GBool -> "decode.bool"
    GBitArray -> "decode.bit_array"
    GOption(inner) -> "decode.optional(" <> gleam_type_to_decoder(inner) <> ")"
    GDate -> "decode.string"
    GTime -> "decode.string"
    GTimestamp -> "decode.string"
    GUuid -> "decode.string"
    GJson -> "decode.string"
  }
}

pub fn gleam_type_to_d1_bind(t: GleamType) -> String {
  case t {
    GInt -> "d1.int"
    GFloat -> "d1.float"
    GString -> "d1.text"
    GBool -> "d1.int"
    GBitArray -> "d1.blob"
    GOption(_) -> "d1.null_value"
    GDate -> "d1.text"
    GTime -> "d1.text"
    GTimestamp -> "d1.text"
    GUuid -> "d1.text"
    GJson -> "d1.text"
  }
}

pub fn gleam_type_to_turso_value(t: GleamType) -> String {
  case t {
    GInt -> "turso.int"
    GFloat -> "turso.float"
    GString -> "turso.text"
    GBool -> "turso.int"
    GBitArray -> "turso.blob"
    GOption(_) -> "turso.null_value"
    GDate -> "turso.date"
    GTime -> "turso.time"
    GTimestamp -> "turso.timestamp"
    GUuid -> "turso.uuid"
    GJson -> "turso.json_string"
  }
}

pub fn gleam_type_to_turso_extractor(t: GleamType) -> String {
  case t {
    GInt -> "fn(v) { case v { turso.types.Integer(i) -> i, _ -> 0 } }"
    GFloat -> "fn(v) { case v { turso.types.Float(f) -> f, _ <- 0.0 } }"
    GString -> "fn(v) { case v { turso.types.Text(s) -> s, _ -> \"\" } }"
    GBool -> "fn(v) { case v { turso.types.Integer(i) -> i != 0, _ -> False } }"
    GBitArray -> "fn(v) { case v { turso.types.Blob(b) -> b, _ -> <<>> } }"
    GOption(inner) -> {
      let inner_extractor = gleam_type_to_turso_extractor(inner)
      "fn(v) { case v { turso.types.Null -> None, _ -> Some("
      <> inner_extractor
      <> "(v)) } }"
    }
    GDate -> "fn(v) { case v { turso.types.Text(s) -> s, turso.types.Date(s) -> s, _ -> \"\" } }"
    GTime -> "fn(v) { case v { turso.types.Text(s) -> s, turso.types.Time(s) -> s, _ -> \"\" } }"
    GTimestamp -> "fn(v) { case v { turso.types.Text(s) -> s, turso.types.Timestamp(s) -> s, _ -> \"\" } }"
    GUuid -> "fn(v) { case v { turso.types.Text(s) -> s, turso.types.Uuid(s) -> s, _ -> \"\" } }"
    GJson -> "fn(v) { case v { turso.types.Text(s) -> s, turso.types.JsonString(s) -> s, _ -> \"\" } }"
  }
}
