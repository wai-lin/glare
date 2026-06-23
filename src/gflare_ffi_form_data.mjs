import { Ok, Error, List, NonEmpty } from "./gleam.mjs";

class GleamText {
  constructor(value) {
    this.Text = value;
  }
}

class GleamFile {
  constructor(filename, content_type, data) {
    this.File = [filename, content_type, data];
  }
}

export async function parse_form_data(request) {
  try {
    const fd = await request.formData();
    return new Ok(fd);
  } catch (e) {
    return new Error(`${e}`);
  }
}

export function form_data_get(fd, name) {
  const val = fd.get(name);
  if (val === null || val === undefined) return null;
  if (typeof val === "string") return new GleamText(val);
  return new GleamFile(
    val.name || null,
    val.type || null,
    new Uint8Array(val),
  );
}

export function form_data_get_all(fd, name) {
  const vals = fd.getAll(name);
  return List.fromArray(
    vals.map((val) => {
      if (typeof val === "string") return new GleamText(val);
      return new GleamFile(
        val.name || null,
        val.type || null,
        new Uint8Array(val),
      );
    }),
  );
}

export function form_data_entries(fd) {
  const entries = [];
  for (const [key, val] of fd.entries()) {
    if (typeof val === "string") {
      entries.push([key, new GleamText(val)]);
    } else {
      entries.push([
        key,
        new GleamFile(val.name || null, val.type || null, new Uint8Array(val)),
      ]);
    }
  }
  return List.fromArray(entries);
}
