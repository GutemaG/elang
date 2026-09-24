/** Joins class names, dropping anything falsy. Small enough not to be worth
 * a dependency; the variant maps below do the rest. */
export function cx(...parts: (string | false | null | undefined)[]): string {
  return parts.filter(Boolean).join(' ')
}
