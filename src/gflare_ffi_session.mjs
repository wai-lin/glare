export function clone_with_header(request, name, value) {
  const cloned = request.clone();
  cloned.headers.set(name, value);
  return cloned;
}
