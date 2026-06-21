pub type GleamType {
  GInt
  GFloat
  GString
  GBool
  GBitArray
  GOption(GleamType)
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
  )
}

pub type DbBackend {
  D1
  Turso
}

pub type MigrationFile {
  MigrationFile(
    version: Int,
    name: String,
    path: String,
    sql: String,
  )
}

pub fn gleam_type_to_string(t: GleamType) -> String {
  case t {
    GInt -> "Int"
    GFloat -> "Float"
    GString -> "String"
    GBool -> "Bool"
    GBitArray -> "BitArray"
    GOption(inner) -> "Option(" <> gleam_type_to_string(inner) <> ")"
  }
}

pub fn parse_gleam_type(s: String) -> GleamType {
  case s {
    "Int" -> GInt
    "Float" -> GFloat
    "String" -> GString
    "Bool" -> GBool
    "BitArray" -> GBitArray
    "Option(Int)" -> GOption(GInt)
    "Option(Float)" -> GOption(GFloat)
    "Option(String)" -> GOption(GString)
    "Option(Bool)" -> GOption(GBool)
    "Option(BitArray)" -> GOption(GBitArray)
    _ -> GString
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
  }
}
